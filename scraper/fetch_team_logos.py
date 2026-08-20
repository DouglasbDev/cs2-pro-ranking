"""
Fetches real team logos from prosettings.net and writes them into the
Flutter app's bundled assets, updating teams.logo_url in app_data.db to
point at the local file — same offline-only rule as players.image_url
(fetch_player_images.py): the app never loads a remote URL, only
Image.asset(...).

No Selenium: prosettings.net has no Cloudflare bot-challenge.

Strategy (verified by hand against the live site before writing this):
  1. Fetch https://prosettings.net/teams/ ONCE. Team logos, unlike player
     photos, are already embedded directly in that single listing page —
     no need to visit each team's own profile page. Two sections carry
     them:
       a. The main card grid: `div.common-card.team` blocks, each with
          `<h4><a href="/teams/{slug}/">Display Name</a></h4>` and a
          `.common-card_avatar img` (90x90, the best quality available).
       b. The site nav's "Top teams" dropdown: `li.menu-item a[href*=
          "/teams/"]`, smaller (30x30) but covers a few big-name teams
          that turned out to be missing from the card grid (e.g. Team
          Vitality, Team Spirit, G2 Esports, FaZe Clan).
     We read the real `src` of whichever `<img>` sits next to the matched
     name — never construct the "*-90x90-fitcontain*" filename ourselves,
     since e.g. some logos (Natus Vincere, Astralis, FaZe) are served as
     .svg with no raster filename at all.
  2. Our team names are short org names ("Vitality", "G2", "FaZe",
     "Spirit") while prosettings.net lists fuller official names ("Team
     Vitality", "G2 Esports", "FaZe Clan", "Team Spirit"), so matching
     tries, in order:
       a. Exact (case-insensitive) text match.
       b. Our name as a whole word inside the site's display name,
          case-insensitive (e.g. "G2" inside "G2 Esports"). If this
          matches multiple distinct site entries that all point at the
          *same* logo image (true for G2's Esports/Gozen/Ares sub-teams,
          and for Falcons' Esports/Vega/Force sub-teams — one shared org
          logo), that's not really ambiguous and we just use it.
       c. Punctuation-insensitive (letters+digits only, lowercased) match,
          same dedup-by-image rule.
     If genuinely distinct logo images remain ambiguous, we try to break
     the tie by checking which candidate's own team page mentions the
     player-roster's known country; if that doesn't resolve it uniquely,
     we skip the team rather than guess.
  3. A handful of teams may not resolve at all — e.g. "Monte" 404s from
     both index sources, and guessing its URL directly
     (prosettings.net/teams/monte/) turns out to be a soft-404 (HTTP 200
     but a generic homepage shell, not real team content) rather than a
     clean 404, which is exactly the kind of silent failure this script
     is written to detect (checked via the resolved page's own team name
     text) and skip instead of trusting a 200 status code blindly.
  4. Logos are fetched and re-encoded as genuine PNG via Pillow. Three of
     our teams' logos are SVG-only on the site (Natus Vincere, Astralis,
     FaZe) — Pillow can't rasterize SVG, and the obvious choice
     (cairosvg) needs a system Cairo install that isn't present here, so
     SVGs are rasterized with resvg-py instead (Rust-backed, ships
     prebuilt wheels, no native Cairo dependency).

Usage:
    pip install -r requirements.txt
    python fetch_team_logos.py
"""

from __future__ import annotations

import io
import logging
import re
import sqlite3
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import requests
import resvg_py
from bs4 import BeautifulSoup
from PIL import Image

BASE_URL = "https://prosettings.net"
TEAMS_URL = f"{BASE_URL}/teams/"

REQUEST_DELAY_SECONDS = 0.8
REQUEST_TIMEOUT_SECONDS = 20

FLUTTER_APP_DIR = Path(__file__).parent.parent / "flutter_app"
DB_PATH = FLUTTER_APP_DIR / "assets" / "data" / "app_data.db"
TEAM_IMAGES_DIR = FLUTTER_APP_DIR / "assets" / "images" / "teams"

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("fetch_team_logos")


@dataclass
class TeamRow:
    id: int
    hltv_slug: str
    name: str
    country: Optional[str]


@dataclass
class Entry:
    display_name: str
    profile_url: str
    image_src: str


@dataclass
class NameIndex:
    entries: list[Entry] = field(default_factory=list)


def normalize(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", text.lower())


def word_in(short: str, full: str) -> bool:
    return re.search(rf"\b{re.escape(short.lower())}\b", full.lower()) is not None


def fetch_html(session: requests.Session, url: str) -> Optional[str]:
    for attempt in range(1, 3):
        try:
            resp = session.get(url, timeout=REQUEST_TIMEOUT_SECONDS)
            if resp.status_code == 404:
                return None
            resp.raise_for_status()
            return resp.text
        except requests.RequestException as exc:
            log.warning("Attempt %d/2 failed for %s: %s", attempt, url, exc)
            time.sleep(REQUEST_DELAY_SECONDS)
    log.error("Giving up on %s", url)
    return None


def build_name_index(html: str) -> NameIndex:
    soup = BeautifulSoup(html, "lxml")
    index = NameIndex()

    for card in soup.select("div.common-card.team"):
        link = card.select_one("h4 a")
        img = card.select_one(".common-card_avatar img")
        if link and img and img.get("src"):
            index.entries.append(Entry(link.get_text(strip=True), link["href"], img["src"]))

    for link in soup.select("li.menu-item a[href*='/teams/']"):
        img = link.select_one("img")
        if img and img.get("src"):
            index.entries.append(
                Entry(link.get_text(strip=True), link["href"], img["src"])
            )

    log.info("Indexed %d team entries from %s", len(index.entries), TEAMS_URL)
    return index


def image_identity(url: str) -> str:
    """The same logo is often listed twice at different sizes (a 90x90 in
    the main card grid, a 30x30 in the nav dropdown) — e.g.
    'furia-90x90-fitcontain.png' and 'furia-30x30-fitcontain-s1.png' are the
    *same* logo, not a conflict. Strip the '-{W}x{H}...' suffix so both
    collapse to the same identity ('furia') and only genuinely different
    images (different base name, e.g. 'team-spirit' vs
    'team-spirit-academy') are treated as distinct candidates."""
    filename = url.rsplit("/", 1)[-1]
    match = re.match(r"(.+?)-\d+x\d+", filename)
    return match.group(1) if match else filename


def image_size(url: str) -> int:
    match = re.search(r"-(\d+)x(\d+)", url)
    return int(match.group(1)) * int(match.group(2)) if match else 0


def group_by_identity(entries: list[Entry]) -> dict[str, list[Entry]]:
    groups: dict[str, list[Entry]] = {}
    for e in entries:
        groups.setdefault(image_identity(e.image_src), []).append(e)
    return groups


def best_image(group: list[Entry]) -> str:
    return max(group, key=lambda e: image_size(e.image_src)).image_src


def disambiguate_by_country(
    session: requests.Session, groups: dict[str, list[Entry]], country: Optional[str]
) -> Optional[str]:
    if not country:
        return None
    matching_groups = []
    for identity, group in groups.items():
        # one HTML check per candidate identity is enough, no need to hit
        # every size-variant's URL (they're the same team's page anyway).
        html = fetch_html(session, group[0].profile_url)
        time.sleep(REQUEST_DELAY_SECONDS)
        if html and country.lower() in html.lower():
            matching_groups.append(group)
    return best_image(matching_groups[0]) if len(matching_groups) == 1 else None


def resolve_logo_src(
    session: requests.Session, team: TeamRow, index: NameIndex
) -> Optional[str]:
    name = team.name

    for candidates in (
        [e for e in index.entries if e.display_name.lower() == name.lower()],
        [e for e in index.entries if word_in(name, e.display_name)],
        [e for e in index.entries if normalize(name) == normalize(e.display_name)],
    ):
        if not candidates:
            continue
        groups = group_by_identity(candidates)
        if len(groups) == 1:
            return best_image(next(iter(groups.values())))

        # Still multiple distinct logos (e.g. "Spirit" word-matches both
        # "Team Spirit" and "Team Spirit Academy"): prefer whichever site
        # display name is closest in length to our own — the shorter,
        # closer match is virtually always the main team, not a sibling
        # academy/female/secondary roster.
        by_shortest_name = sorted(
            groups.items(), key=lambda kv: min(len(e.display_name) for e in kv[1])
        )
        if len(by_shortest_name) > 1 and len(by_shortest_name[0][1][0].display_name) < len(
            by_shortest_name[1][1][0].display_name
        ):
            return best_image(by_shortest_name[0][1])

        resolved = disambiguate_by_country(session, groups, team.country)
        if resolved:
            log.info("Disambiguated %r by country", name)
            return resolved
        log.warning(
            "%r matched %d distinct logos on prosettings.net and country check "
            "didn't resolve it uniquely — trying next tier",
            name, len(groups),
        )

    return None


def download_as_png(session: requests.Session, image_url: str, dest_path: Path) -> bool:
    try:
        resp = session.get(image_url, timeout=REQUEST_TIMEOUT_SECONDS)
        resp.raise_for_status()

        if image_url.lower().endswith(".svg"):
            png_bytes = resvg_py.svg_to_bytes(
                svg_string=resp.content.decode("utf-8"), width=200, height=200
            )
            image = Image.open(io.BytesIO(bytes(png_bytes))).convert("RGBA")
        else:
            image = Image.open(io.BytesIO(resp.content)).convert("RGBA")

        dest_path.parent.mkdir(parents=True, exist_ok=True)
        image.save(dest_path, format="PNG")
        return True
    except Exception as exc:  # noqa: BLE001 - log and continue, never crash the run
        log.warning("Failed to download/convert logo %s: %s", image_url, exc)
        return False


def load_teams(conn: sqlite3.Connection) -> list[TeamRow]:
    rows = conn.execute("SELECT id, hltv_slug, name, country FROM teams").fetchall()
    return [TeamRow(id=r[0], hltv_slug=r[1], name=r[2], country=r[3]) for r in rows]


def update_logo_url(conn: sqlite3.Connection, team_id: int, logo_url: Optional[str]) -> None:
    conn.execute("UPDATE teams SET logo_url = ? WHERE id = ?", (logo_url, team_id))
    conn.commit()


def main() -> None:
    if not DB_PATH.exists():
        raise SystemExit(f"Database not found: {DB_PATH} (run import_data.py first)")

    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT})

    conn = sqlite3.connect(DB_PATH)
    teams = load_teams(conn)
    log.info("Loaded %d teams from %s", len(teams), DB_PATH)

    html = fetch_html(session, TEAMS_URL)
    if html is None:
        raise SystemExit(f"Could not fetch {TEAMS_URL} — aborting")
    time.sleep(REQUEST_DELAY_SECONDS)
    index = build_name_index(html)

    found = 0
    not_found: list[str] = []

    for i, team in enumerate(teams, start=1):
        log.info("[%d/%d] %s", i, len(teams), team.name)

        logo_src = resolve_logo_src(session, team, index)
        if logo_src is None:
            log.info("  not found on prosettings.net")
            update_logo_url(conn, team.id, None)
            not_found.append(team.name)
            continue

        dest_path = TEAM_IMAGES_DIR / f"{team.hltv_slug}.png"
        time.sleep(REQUEST_DELAY_SECONDS)
        if download_as_png(session, logo_src, dest_path):
            asset_path = f"assets/images/teams/{team.hltv_slug}.png"
            update_logo_url(conn, team.id, asset_path)
            found += 1
        else:
            update_logo_url(conn, team.id, None)
            not_found.append(team.name)

    conn.close()

    print()
    print("=== Team logo fetch summary ===")
    print(f"Teams processed: {len(teams)}")
    print(f"Logos downloaded: {found}")
    print(f"Not found:        {len(not_found)}")
    if not_found:
        print("  " + ", ".join(not_found))
    print(f"Logos saved to: {TEAM_IMAGES_DIR}")
    print(f"Database updated: {DB_PATH}")


if __name__ == "__main__":
    main()
