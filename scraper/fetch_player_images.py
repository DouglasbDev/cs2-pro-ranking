"""
Fetches real player photos from prosettings.net and writes them into the
Flutter app's bundled assets, updating players.image_url in app_data.db to
point at the local file (never a remote URL — the app is 100% offline).

No Selenium: prosettings.net has no Cloudflare bot-challenge, plain
requests + BeautifulSoup works.

Strategy (verified by hand against the live site before writing this):
  1. Fetch https://prosettings.net/lists/cs2/ ONCE. It's a single page (no
     pagination) containing a gear-comparison table with one row per CS2
     player: `<span class="name"><a href="/players/{slug}/">{Nickname}</a>`.
     This gives us ~900 (display_name, profile_url) pairs to match our 96
     players against — this is the "listing page" lookup the task asked
     for, and it's what lets us find a player's *real* profile URL instead
     of guessing it from the nickname.
  2. Match each of our nicknames against that index, in order of
     confidence:
       a. Exact (case-sensitive) text match.
       b. Case-insensitive match, only if it resolves to exactly one URL.
       c. Punctuation-insensitive match (letters+digits only, lowercased),
          only if it resolves to exactly one URL — catches cases like our
          "huNter-" vs. the site's "huNter" (trailing dash dropped).
       If more than one candidate URL remains ambiguous at any tier, we
       break the tie using the player's known team name (checked against
       each candidate page's HTML) instead of guessing.
     This matters in practice: prosettings.net has real name collisions,
     e.g. both "NiKo" (-> /players/niko/, our Bosnian NiKo) and "niko"
     (-> /players/niko-danish/, a different player) exist; a naive
     lowercase-only match would have silently grabbed the wrong one.
  3. On the resolved profile page, the real photo is the <img> with
     container-class="avatar_player-img" (verified on multiple profile
     pages) — we read its actual `src` attribute rather than constructing
     the "*-220x220-fitcontain-q99-gbNNN-s1.*" URL ourselves, since the gb
     number and even the file extension (.png vs .webp) vary per image.
  4. The fetched image (whatever format it actually is) is decoded and
     re-encoded as PNG via Pillow, so the saved file genuinely matches its
     assets/images/players/{hltv_slug}.png name/extension.
  5. Players not found on prosettings.net (confirmed against the full
     listing, not just a 404 on a guessed URL) are logged and skipped —
     image_url is left/set to NULL for them, the run continues.

Usage:
    pip install -r requirements.txt
    python fetch_player_images.py
"""

from __future__ import annotations

import io
import logging
import random
import re
import sqlite3
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import requests
from bs4 import BeautifulSoup
from PIL import Image

BASE_URL = "https://prosettings.net"
LIST_URL = f"{BASE_URL}/lists/cs2/"

MIN_DELAY_SECONDS = 0.6
MAX_DELAY_SECONDS = 1.4
REQUEST_TIMEOUT_SECONDS = 20

FLUTTER_APP_DIR = Path(__file__).parent.parent / "flutter_app"
DB_PATH = FLUTTER_APP_DIR / "assets" / "data" / "app_data.db"
PLAYER_IMAGES_DIR = FLUTTER_APP_DIR / "assets" / "images" / "players"

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("fetch_player_images")


@dataclass
class PlayerRow:
    id: int
    hltv_slug: str
    nickname: str
    team_name: Optional[str]


@dataclass
class NameIndex:
    by_exact: dict[str, str] = field(default_factory=dict)
    by_lower: dict[str, list[tuple[str, str]]] = field(default_factory=dict)
    by_normalized: dict[str, list[tuple[str, str]]] = field(default_factory=dict)


def normalize(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", text.lower())


def polite_delay() -> None:
    time.sleep(random.uniform(MIN_DELAY_SECONDS, MAX_DELAY_SECONDS))


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
            polite_delay()
    log.error("Giving up on %s", url)
    return None


def build_name_index(html: str) -> NameIndex:
    soup = BeautifulSoup(html, "lxml")
    index = NameIndex()
    for link in soup.select("span.name a[href]"):
        name = link.get_text(strip=True)
        url = link["href"]
        if not name or "/players/" not in url:
            continue
        index.by_exact[name] = url
        index.by_lower.setdefault(name.lower(), []).append((name, url))
        index.by_normalized.setdefault(normalize(name), []).append((name, url))
    log.info(
        "Indexed %d distinct player names from %s",
        len(index.by_exact), LIST_URL,
    )
    return index


def dedupe_urls(candidates: list[tuple[str, str]]) -> list[str]:
    seen = []
    for _, url in candidates:
        if url not in seen:
            seen.append(url)
    return seen


def disambiguate_by_team(
    session: requests.Session, candidate_urls: list[str], team_name: Optional[str]
) -> Optional[str]:
    if not team_name:
        return None
    matches = []
    for url in candidate_urls:
        html = fetch_html(session, url)
        polite_delay()
        if html and team_name.lower() in html.lower():
            matches.append(url)
    return matches[0] if len(matches) == 1 else None


def resolve_player_url(
    session: requests.Session, player: PlayerRow, index: NameIndex
) -> Optional[str]:
    nickname = player.nickname

    if nickname in index.by_exact:
        return index.by_exact[nickname]

    lower_candidates = index.by_lower.get(nickname.lower(), [])
    lower_urls = dedupe_urls(lower_candidates)
    if len(lower_urls) == 1:
        return lower_urls[0]

    norm_candidates = index.by_normalized.get(normalize(nickname), [])
    norm_urls = dedupe_urls(norm_candidates)
    if len(norm_urls) == 1:
        return norm_urls[0]

    # Ambiguous (multiple distinct candidates) — try to break the tie using
    # the player's known team instead of guessing.
    all_candidates = dedupe_urls(lower_candidates + norm_candidates)
    if len(all_candidates) > 1:
        resolved = disambiguate_by_team(session, all_candidates, player.team_name)
        if resolved:
            log.info("Disambiguated %r by team -> %s", nickname, resolved)
            return resolved
        log.warning(
            "%r matched %d candidates on prosettings.net and team check "
            "didn't resolve it uniquely — skipping: %s",
            nickname, len(all_candidates), all_candidates,
        )
        return None

    return None


def extract_avatar_src(html: str) -> Optional[str]:
    soup = BeautifulSoup(html, "lxml")
    img = soup.find("img", attrs={"container-class": "avatar_player-img"})
    if img is None:
        # Fallback: first WordPress featured image on the page.
        img = soup.find("img", class_="wp-post-image")
    if img is None or not img.get("src"):
        return None
    return img["src"]


def download_as_png(session: requests.Session, image_url: str, dest_path: Path) -> bool:
    try:
        resp = session.get(image_url, timeout=REQUEST_TIMEOUT_SECONDS)
        resp.raise_for_status()
        image = Image.open(io.BytesIO(resp.content)).convert("RGBA")
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        image.save(dest_path, format="PNG")
        return True
    except Exception as exc:  # noqa: BLE001 - log and continue, never crash the run
        log.warning("Failed to download/convert image %s: %s", image_url, exc)
        return False


def load_players(conn: sqlite3.Connection) -> list[PlayerRow]:
    rows = conn.execute(
        """
        SELECT p.id, p.hltv_slug, p.nickname, t.name AS team_name
        FROM players p
        LEFT JOIN teams t ON t.id = p.team_id
        """
    ).fetchall()
    return [PlayerRow(id=r[0], hltv_slug=r[1], nickname=r[2], team_name=r[3]) for r in rows]


def update_image_url(conn: sqlite3.Connection, player_id: int, image_url: Optional[str]) -> None:
    conn.execute("UPDATE players SET image_url = ? WHERE id = ?", (image_url, player_id))
    conn.commit()


def main() -> None:
    if not DB_PATH.exists():
        raise SystemExit(f"Database not found: {DB_PATH} (run import_data.py first)")

    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT})

    conn = sqlite3.connect(DB_PATH)
    players = load_players(conn)
    log.info("Loaded %d players from %s", len(players), DB_PATH)

    list_html = fetch_html(session, LIST_URL)
    if list_html is None:
        raise SystemExit(f"Could not fetch {LIST_URL} — aborting")
    polite_delay()
    index = build_name_index(list_html)

    found = 0
    not_found: list[str] = []

    for i, player in enumerate(players, start=1):
        log.info("[%d/%d] %s", i, len(players), player.nickname)

        profile_url = resolve_player_url(session, player, index)
        if profile_url is None:
            log.info("  not found on prosettings.net")
            update_image_url(conn, player.id, None)
            not_found.append(player.nickname)
            continue

        profile_html = fetch_html(session, profile_url)
        polite_delay()
        if profile_html is None:
            not_found.append(player.nickname)
            update_image_url(conn, player.id, None)
            continue

        avatar_src = extract_avatar_src(profile_html)
        if avatar_src is None:
            log.warning("  no avatar image found on %s", profile_url)
            update_image_url(conn, player.id, None)
            not_found.append(player.nickname)
            continue

        dest_path = PLAYER_IMAGES_DIR / f"{player.hltv_slug}.png"
        polite_delay()
        if download_as_png(session, avatar_src, dest_path):
            asset_path = f"assets/images/players/{player.hltv_slug}.png"
            update_image_url(conn, player.id, asset_path)
            found += 1
        else:
            update_image_url(conn, player.id, None)
            not_found.append(player.nickname)

    conn.close()

    print()
    print("=== Image fetch summary ===")
    print(f"Players processed: {len(players)}")
    print(f"Images downloaded: {found}")
    print(f"Not found:         {len(not_found)}")
    if not_found:
        print("  " + ", ".join(not_found))
    print(f"Images saved to: {PLAYER_IMAGES_DIR}")
    print(f"Database updated: {DB_PATH}")


if __name__ == "__main__":
    main()
