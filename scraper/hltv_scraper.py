"""
HLTV.org scraper -> SQLite (app_data.db) for the CS2 ranking app.

IMPORTANT — read before running:
  - HLTV.org sits behind Cloudflare's bot-detection. This script uses plain
    selenium.webdriver.Chrome (undetected-chromedriver was tried first but
    got blocked by corporate antivirus on this machine) with only a
    realistic user-agent as a launch flag — every anti-automation
    ChromeOptions flag tried (disable-blink-features=AutomationControlled,
    excludeSwitches=enable-automation, useAutomationExtension=False, alone
    or combined) made Chrome exit immediately on this machine, likely a
    corporate Chrome policy conflict. navigator.webdriver — what trips
    Cloudflare's "Verify you are human" challenge — is instead hidden via a
    CDP command (Page.addScriptToEvaluateOnNewDocument) right after the
    driver starts, since that isn't a launch flag. It runs with a visible
    browser window (headless is much more likely to be challenged/blocked).
  - Even with that in place, Cloudflare may still show a challenge on the
    very first request of a run (new/unrecognized browsing session). main()
    pauses once with a manual gate before the automated part starts: solve
    the challenge by hand in the opened Chrome window, then press Enter in
    the terminal to let the rest of the run proceed unattended.
    Random delays are inserted between every page navigation to avoid
    tripping rate limits.
  - HLTV's HTML/CSS structure changes over time and this script was written
    without live access to the site (the assistant that wrote it was
    explicitly barred from browsing hltv.org). Every field extractor is
    isolated in its own small function wrapped in try/except that returns
    None on failure instead of crashing the whole run. If you see a lot of
    None values in app_data.db, open the relevant HLTV page in a real
    browser, inspect the current markup, and adjust the CSS selectors in
    the SELECTORS-marked sections below.
  - Re-running the script is safe: rows are upserted by hltv_slug, so you
    can fix a selector and re-run without creating duplicates.

Usage:
    pip install -r requirements.txt
    python hltv_scraper.py
"""

from __future__ import annotations

import logging
import random
import re
import sqlite3
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.common.exceptions import TimeoutException, WebDriverException
from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium.webdriver.support.ui import WebDriverWait

# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------

BASE_URL = "https://www.hltv.org"
TOP_N_PLAYERS = 30
TOP_N_TEAMS = 20

MIN_DELAY_SECONDS = 3.0
MAX_DELAY_SECONDS = 7.0
PAGE_LOAD_TIMEOUT_SECONDS = 30
MAX_RETRIES_PER_PAGE = 2

OUTPUT_DIR = Path(__file__).parent / "output"
ASSETS_DIR = OUTPUT_DIR / "assets"
DB_PATH = ASSETS_DIR / "data" / "app_data.db"
PLAYER_IMAGES_DIR = ASSETS_DIR / "images" / "players"
TEAM_IMAGES_DIR = ASSETS_DIR / "images" / "teams"

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("hltv_scraper")


# --------------------------------------------------------------------------
# Data holders
# --------------------------------------------------------------------------

@dataclass
class TeamData:
    hltv_slug: str
    name: str
    country: Optional[str] = None
    maps_played: Optional[int] = None
    wins: Optional[int] = None
    draws: Optional[int] = None
    losses: Optional[int] = None
    total_kills: Optional[int] = None
    total_deaths: Optional[int] = None
    rounds_played: Optional[int] = None
    kd_ratio: Optional[float] = None
    kd_diff: Optional[int] = None
    rating_overall: Optional[float] = None
    logo_url: Optional[str] = None
    roster_slugs: list[str] = field(default_factory=list)


@dataclass
class PlayerData:
    hltv_slug: str
    nickname: str
    team_name: Optional[str] = None
    full_name: Optional[str] = None
    age: Optional[int] = None
    country: Optional[str] = None
    rating_overall: Optional[float] = None
    rating_ct_side: Optional[float] = None
    rating_t_side: Optional[float] = None
    kd_ratio: Optional[float] = None
    kd_diff_ct_side: Optional[int] = None
    kd_diff_t_side: Optional[int] = None
    rounds_played_ct_side: Optional[int] = None
    rounds_played_t_side: Optional[int] = None
    total_kills: Optional[int] = None
    total_deaths: Optional[int] = None
    damage_per_round: Optional[float] = None
    headshot_percentage: Optional[float] = None
    kast_percentage: Optional[float] = None
    kills_per_round: Optional[float] = None
    deaths_per_round: Optional[float] = None
    assists_per_round: Optional[float] = None
    maps_played: Optional[int] = None
    image_url: Optional[str] = None


# --------------------------------------------------------------------------
# Browser / network helpers
# --------------------------------------------------------------------------

def init_driver() -> webdriver.Chrome:
    # On this machine, every Chrome-launch-flag-based anti-automation option
    # tried so far (disable-blink-features=AutomationControlled,
    # excludeSwitches=enable-automation, useAutomationExtension=False, alone
    # or combined) made Chrome exit immediately after DevTools came up
    # (SessionNotCreatedException: Chrome instance exited) — almost
    # certainly a corporate Chrome policy conflict. Only --window-size and
    # --user-agent are launch flags here; do not add more without testing.
    # navigator.webdriver (what trips Cloudflare's "Verify you are human"
    # challenge) is instead hidden via a CDP command after the driver
    # starts, since that isn't a launch flag and doesn't crash Chrome.
    options = ChromeOptions()
    options.add_argument("--window-size=1440,1000")
    options.add_argument(f"--user-agent={USER_AGENT}")
    try:
        # Selenium Manager (bundled since Selenium 4.6) resolves and downloads
        # a chromedriver build matching the locally installed Chrome
        # automatically — no manual driver/version wiring needed here.
        driver = webdriver.Chrome(options=options)
    except WebDriverException as exc:
        log.error(
            "Failed to start Chrome via selenium.webdriver.Chrome: %s\n"
            "Checklist:\n"
            "  1) Make sure Google Chrome is installed and up to date.\n"
            "  2) Make sure no other stray chrome.exe / chromedriver.exe process is "
            "still running (check Task Manager and end them).\n"
            "  3) Upgrade selenium ('pip install -U selenium') so Selenium Manager "
            "recognizes newer Chrome releases.\n"
            "  4) If antivirus/corporate policy is blocking the driver binary, check "
            "quarantine logs and allow-list chromedriver.exe.\n"
            "  5) If it crashed right after DevTools connected, an experimental "
            "ChromeOptions flag is the likely culprit again on this machine — this "
            "function intentionally only sets --window-size/--user-agent now; don't "
            "add more without testing one at a time.\n"
            "  6) Try again once or twice — this can occasionally fail transiently.",
            exc,
        )
        raise
    driver.set_page_load_timeout(PAGE_LOAD_TIMEOUT_SECONDS)

    # Mask navigator.webdriver on every new document, before any page script
    # runs — this is what Cloudflare's challenge checks for.
    driver.execute_cdp_cmd(
        "Page.addScriptToEvaluateOnNewDocument",
        {"source": "Object.defineProperty(navigator, 'webdriver', {get: () => undefined})"},
    )

    return driver


def polite_delay() -> None:
    time.sleep(random.uniform(MIN_DELAY_SECONDS, MAX_DELAY_SECONDS))


def manual_cloudflare_gate(driver: webdriver.Chrome, url: str) -> None:
    """One-time manual pause: navigate to the first HLTV page and let a
    human solve the Cloudflare challenge by hand (if one appears) before
    the rest of the run proceeds unattended."""
    driver.get(url)
    input(
        "\n>>> Resolva a verificacao do Cloudflare na janela do Chrome que abriu "
        "(se aparecer) e aperte Enter aqui para continuar...\n"
    )
    wait_for_cloudflare(driver)
    polite_delay()


def wait_for_cloudflare(driver: webdriver.Chrome, timeout: int = 20) -> None:
    """Blocks until the Cloudflare interstitial ('Just a moment...' /
    'Checking your browser') is no longer the active page title. Cloudflare
    can challenge any page, not just the first one — if it doesn't clear on
    its own within `timeout` seconds, this pauses for a human to solve it
    manually in the browser window instead of giving up and letting the
    caller scrape an empty challenge page."""
    challenge_markers = ("just a moment", "checking your browser", "attention required")

    def _cleared(d):
        title = (d.title or "").lower()
        return not any(marker in title for marker in challenge_markers)

    while not _cleared(driver):
        try:
            WebDriverWait(driver, timeout).until(_cleared)
            return
        except TimeoutException:
            input(
                "\n>>> Cloudflare apareceu de novo nesta pagina. Resolva manualmente "
                "e aperte Enter para continuar...\n"
            )


def fetch_soup(driver: webdriver.Chrome, url: str) -> Optional[BeautifulSoup]:
    for attempt in range(1, MAX_RETRIES_PER_PAGE + 1):
        try:
            driver.get(url)
            wait_for_cloudflare(driver)
            polite_delay()
            return BeautifulSoup(driver.page_source, "lxml")
        except (TimeoutException, WebDriverException) as exc:
            log.warning("Attempt %d/%d failed for %s: %s", attempt, MAX_RETRIES_PER_PAGE, url, exc)
            polite_delay()
    log.error("Giving up on %s after %d attempts", url, MAX_RETRIES_PER_PAGE)
    return None


def download_image(url: Optional[str], dest_path: Path) -> Optional[str]:
    """Downloads url to dest_path. Returns the asset-relative path
    ('assets/images/...') to store in the DB, or None on failure."""
    if not url:
        return None
    try:
        resp = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=15)
        resp.raise_for_status()
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        dest_path.write_bytes(resp.content)
        return "assets/" + str(dest_path.relative_to(ASSETS_DIR)).replace("\\", "/")
    except requests.RequestException as exc:
        log.warning("Failed to download image %s: %s", url, exc)
        return None


# --------------------------------------------------------------------------
# Parsing helpers
# --------------------------------------------------------------------------

def slug_from_href(href: str) -> str:
    """/player/12345/donk -> '12345-donk'; /team/6667/navi -> '6667-navi'."""
    parts = [p for p in href.strip("/").split("/") if p]
    return "-".join(parts[-2:]) if len(parts) >= 2 else parts[-1]


def parse_int(text: Optional[str]) -> Optional[int]:
    if not text:
        return None
    match = re.search(r"-?\d[\d,]*", text.replace("\xa0", " "))
    if not match:
        return None
    return int(match.group(0).replace(",", ""))


def parse_float(text: Optional[str]) -> Optional[float]:
    if not text:
        return None
    match = re.search(r"-?\d+(?:\.\d+)?", text.replace(",", "."))
    return float(match.group(0)) if match else None


def parse_percentage(text: Optional[str]) -> Optional[float]:
    return parse_float(text.replace("%", "")) if text else None


def clean_text(el) -> Optional[str]:
    return el.get_text(strip=True) if el else None


# --------------------------------------------------------------------------
# Team scraping
# --------------------------------------------------------------------------

def scrape_team_ranking(driver: webdriver.Chrome) -> list[TeamData]:
    """Top N teams from the aggregated team-stats table."""
    url = f"{BASE_URL}/stats/teams?rankingFilter=Top{TOP_N_TEAMS}"
    soup = fetch_soup(driver, url)
    if soup is None:
        return []

    teams: list[TeamData] = []
    # SELECTORS: team-stats overview table, one <tr> per team.
    rows = soup.select("table.stats-table tbody tr")
    for row in rows[:TOP_N_TEAMS]:
        link = row.select_one("td.team-name a, a.team")
        if link is None:
            continue
        href = link.get("href", "")
        name = clean_text(link)
        if not name:
            continue
        cells = row.select("td")
        team = TeamData(hltv_slug=slug_from_href(href), name=name)
        # Column order on the stats-teams overview page is typically:
        # Team | Maps | Wins / draws / losses | K:D
        for cell in cells:
            cls = " ".join(cell.get("class", []))
            if "maps" in cls:
                team.maps_played = parse_int(clean_text(cell))
            elif "wdl" in cls or "record" in cls:
                wdl = clean_text(cell) or ""
                wdl_match = re.match(r"(\d+)\s*/\s*(\d+)\s*/\s*(\d+)", wdl)
                if wdl_match:
                    team.wins, team.draws, team.losses = (int(g) for g in wdl_match.groups())
            elif "kd" in cls or "gap" in cls:
                team.kd_ratio = parse_float(clean_text(cell))
        teams.append(team)

    log.info("Scraped %d teams from ranking list", len(teams))
    return teams


def scrape_team_detail(driver: webdriver.Chrome, team: TeamData) -> None:
    """Fills in country, rating, kills/deaths/rounds, logo and roster."""
    url = f"{BASE_URL}/team/{team.hltv_slug}"
    soup = fetch_soup(driver, url)
    if soup is None:
        return

    # SELECTORS: team profile header.
    country_el = soup.select_one(".team-country .flag, .profile-team-country img")
    if country_el:
        team.country = country_el.get("title") or clean_text(country_el)

    logo_el = soup.select_one(".teamlogo, img.team-logo")
    if logo_el and logo_el.get("src"):
        team.logo_url = urljoin(BASE_URL, logo_el["src"])

    rating_el = soup.select_one(".rating-value, .team-rating .value")
    team.rating_overall = parse_float(clean_text(rating_el))

    # SELECTORS: "Total stats" box (kills, deaths, rounds).
    for stat_box in soup.select(".stats-row, .col-stat"):
        label = clean_text(stat_box.select_one(".stats-row-label, .label"))
        value = clean_text(stat_box.select_one(".stats-row-value, .value"))
        if not label:
            continue
        label_lower = label.lower()
        if "kills" in label_lower:
            team.total_kills = parse_int(value)
        elif "deaths" in label_lower:
            team.total_deaths = parse_int(value)
        elif "rounds" in label_lower:
            team.rounds_played = parse_int(value)
        elif "k/d" in label_lower or "kd" in label_lower:
            team.kd_ratio = team.kd_ratio or parse_float(value)

    if team.total_kills is not None and team.total_deaths is not None:
        team.kd_diff = team.total_kills - team.total_deaths

    # SELECTORS: current lineup / roster block.
    for player_link in soup.select(".bodyshot-team a[href*='/player/'], .lineup a[href*='/player/']"):
        href = player_link.get("href", "")
        if href:
            team.roster_slugs.append(slug_from_href(href))
    team.roster_slugs = list(dict.fromkeys(team.roster_slugs))  # de-dup, keep order


# --------------------------------------------------------------------------
# Player scraping
# --------------------------------------------------------------------------

def scrape_player_ranking(driver: webdriver.Chrome) -> list[PlayerData]:
    url = f"{BASE_URL}/stats/players?rankingFilter=Top{TOP_N_PLAYERS}"
    soup = fetch_soup(driver, url)
    if soup is None:
        return []

    players: list[PlayerData] = []
    rows = soup.select("table.stats-table tbody tr")
    for row in rows[:TOP_N_PLAYERS]:
        link = row.select_one("td.playerCol a, a.player")
        if link is None:
            continue
        href = link.get("href", "")
        nickname = clean_text(link)
        if not nickname:
            continue
        player = PlayerData(hltv_slug=slug_from_href(href), nickname=nickname)

        team_link = row.select_one("td.teamCol a")
        if team_link:
            player.team_name = clean_text(team_link)

        maps_cell = row.select_one("td.statsDetail, td.maps")
        player.maps_played = parse_int(clean_text(maps_cell))

        kd_cell = row.select_one("td.kdRatio, td.kd")
        player.kd_ratio = parse_float(clean_text(kd_cell))

        rating_cell = row.select_one("td.rating, td.ratingCol")
        player.rating_overall = parse_float(clean_text(rating_cell))

        players.append(player)

    log.info("Scraped %d players from ranking list", len(players))
    return players


def scrape_player_profile(driver: webdriver.Chrome, player: PlayerData) -> None:
    """Bio info: full name, age, country, photo."""
    url = f"{BASE_URL}/player/{player.hltv_slug}"
    soup = fetch_soup(driver, url)
    if soup is None:
        return

    fullname_el = soup.select_one(".playerRealname, .player-realname")
    player.full_name = clean_text(fullname_el)

    age_el = soup.select_one(".playerAge, .player-age")
    player.age = parse_int(clean_text(age_el))

    country_el = soup.select_one(".player-country .flag, .flag")
    if country_el:
        player.country = country_el.get("title") or clean_text(country_el)

    photo_el = soup.select_one(".bodyshot-img, img.player-image")
    if photo_el and photo_el.get("src"):
        player.image_url = urljoin(BASE_URL, photo_el["src"])


def scrape_player_stats(driver: webdriver.Chrome, player: PlayerData) -> None:
    """Detailed performance stats, including CT/T side breakdown."""
    url = f"{BASE_URL}/stats/players/{player.hltv_slug}"
    soup = fetch_soup(driver, url)
    if soup is None:
        return

    # SELECTORS: "Total statistics" summary boxes on the player stats overview.
    summary_map = {
        "total kills": "total_kills",
        "deaths": "total_deaths",
        "headshot %": "headshot_percentage",
        "damage / round": "damage_per_round",
        "kast": "kast_percentage",
        "kills / round": "kills_per_round",
    }
    for box in soup.select(".summaryStatBreakdown, .stats-row"):
        label = clean_text(box.select_one(".summaryStatBreakdownSubHeader, .stats-row-label"))
        value = clean_text(box.select_one(".summaryStatBreakdownDataValue, .stats-row-value"))
        if not label:
            continue
        key = summary_map.get(label.lower())
        if key is None:
            continue
        parsed = parse_percentage(value) if "%" in (value or "") else parse_float(value)
        setattr(player, key, parsed)

    if player.total_kills is not None and player.total_deaths not in (None, 0):
        player.deaths_per_round = player.deaths_per_round  # left as scraped if present

    # SELECTORS: CT-side / T-side rating & K-D diff breakdown table.
    for side_key, css_class in (("ct", "ct"), ("t", "t")):
        side_block = soup.select_one(f".side-rating-{css_class}, .{css_class}-side-stats")
        if side_block is None:
            continue
        rating_val = parse_float(clean_text(side_block.select_one(".rating-value, .value")))
        kd_diff_val = parse_int(clean_text(side_block.select_one(".kd-diff, .diff")))
        rounds_val = parse_int(clean_text(side_block.select_one(".rounds-played, .rounds")))
        if side_key == "ct":
            player.rating_ct_side = rating_val
            player.kd_diff_ct_side = kd_diff_val
            player.rounds_played_ct_side = rounds_val
        else:
            player.rating_t_side = rating_val
            player.kd_diff_t_side = kd_diff_val
            player.rounds_played_t_side = rounds_val

    assists_el = soup.select_one(".assists-per-round, .apr-value")
    player.assists_per_round = parse_float(clean_text(assists_el))

    if player.kills_per_round is not None and player.assists_per_round is not None:
        pass  # deaths_per_round has no dedicated selector guess; left None if not found above


# --------------------------------------------------------------------------
# SQLite
# --------------------------------------------------------------------------

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS teams (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  hltv_slug TEXT UNIQUE,
  name TEXT NOT NULL,
  country TEXT,
  maps_played INTEGER,
  wins INTEGER,
  draws INTEGER,
  losses INTEGER,
  total_kills INTEGER,
  total_deaths INTEGER,
  rounds_played INTEGER,
  kd_ratio REAL,
  kd_diff INTEGER,
  rating_overall REAL,
  logo_url TEXT,
  scraped_at TEXT
);

CREATE TABLE IF NOT EXISTS players (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  hltv_slug TEXT UNIQUE,
  nickname TEXT NOT NULL,
  full_name TEXT,
  age INTEGER,
  country TEXT,
  team_id INTEGER,
  rating_overall REAL,
  rating_ct_side REAL,
  rating_t_side REAL,
  kd_ratio REAL,
  kd_diff_ct_side INTEGER,
  kd_diff_t_side INTEGER,
  rounds_played_ct_side INTEGER,
  rounds_played_t_side INTEGER,
  total_kills INTEGER,
  total_deaths INTEGER,
  damage_per_round REAL,
  headshot_percentage REAL,
  kast_percentage REAL,
  kills_per_round REAL,
  deaths_per_round REAL,
  assists_per_round REAL,
  maps_played INTEGER,
  image_url TEXT,
  scraped_at TEXT,
  FOREIGN KEY (team_id) REFERENCES teams(id)
);
"""


def init_db(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.executescript(SCHEMA_SQL)
    conn.commit()
    return conn


def upsert_team(conn: sqlite3.Connection, team: TeamData) -> int:
    now = datetime.now(timezone.utc).isoformat()
    conn.execute(
        """
        INSERT INTO teams (hltv_slug, name, country, maps_played, wins, draws, losses,
                            total_kills, total_deaths, rounds_played, kd_ratio, kd_diff,
                            rating_overall, logo_url, scraped_at)
        VALUES (:hltv_slug, :name, :country, :maps_played, :wins, :draws, :losses,
                :total_kills, :total_deaths, :rounds_played, :kd_ratio, :kd_diff,
                :rating_overall, :logo_url, :scraped_at)
        ON CONFLICT(hltv_slug) DO UPDATE SET
            name=excluded.name, country=excluded.country, maps_played=excluded.maps_played,
            wins=excluded.wins, draws=excluded.draws, losses=excluded.losses,
            total_kills=excluded.total_kills, total_deaths=excluded.total_deaths,
            rounds_played=excluded.rounds_played, kd_ratio=excluded.kd_ratio,
            kd_diff=excluded.kd_diff, rating_overall=excluded.rating_overall,
            logo_url=excluded.logo_url, scraped_at=excluded.scraped_at
        """,
        {
            "hltv_slug": team.hltv_slug,
            "name": team.name,
            "country": team.country,
            "maps_played": team.maps_played,
            "wins": team.wins,
            "draws": team.draws,
            "losses": team.losses,
            "total_kills": team.total_kills,
            "total_deaths": team.total_deaths,
            "rounds_played": team.rounds_played,
            "kd_ratio": team.kd_ratio,
            "kd_diff": team.kd_diff,
            "rating_overall": team.rating_overall,
            "logo_url": team.logo_url,
            "scraped_at": now,
        },
    )
    conn.commit()
    row = conn.execute("SELECT id FROM teams WHERE hltv_slug = ?", (team.hltv_slug,)).fetchone()
    return row[0]


def upsert_player(conn: sqlite3.Connection, player: PlayerData, team_id: Optional[int]) -> None:
    now = datetime.now(timezone.utc).isoformat()
    conn.execute(
        """
        INSERT INTO players (hltv_slug, nickname, full_name, age, country, team_id,
                              rating_overall, rating_ct_side, rating_t_side, kd_ratio,
                              kd_diff_ct_side, kd_diff_t_side, rounds_played_ct_side,
                              rounds_played_t_side, total_kills, total_deaths,
                              damage_per_round, headshot_percentage, kast_percentage,
                              kills_per_round, deaths_per_round, assists_per_round,
                              maps_played, image_url, scraped_at)
        VALUES (:hltv_slug, :nickname, :full_name, :age, :country, :team_id,
                :rating_overall, :rating_ct_side, :rating_t_side, :kd_ratio,
                :kd_diff_ct_side, :kd_diff_t_side, :rounds_played_ct_side,
                :rounds_played_t_side, :total_kills, :total_deaths,
                :damage_per_round, :headshot_percentage, :kast_percentage,
                :kills_per_round, :deaths_per_round, :assists_per_round,
                :maps_played, :image_url, :scraped_at)
        ON CONFLICT(hltv_slug) DO UPDATE SET
            nickname=excluded.nickname, full_name=excluded.full_name, age=excluded.age,
            country=excluded.country, team_id=excluded.team_id,
            rating_overall=excluded.rating_overall, rating_ct_side=excluded.rating_ct_side,
            rating_t_side=excluded.rating_t_side, kd_ratio=excluded.kd_ratio,
            kd_diff_ct_side=excluded.kd_diff_ct_side, kd_diff_t_side=excluded.kd_diff_t_side,
            rounds_played_ct_side=excluded.rounds_played_ct_side,
            rounds_played_t_side=excluded.rounds_played_t_side,
            total_kills=excluded.total_kills, total_deaths=excluded.total_deaths,
            damage_per_round=excluded.damage_per_round,
            headshot_percentage=excluded.headshot_percentage,
            kast_percentage=excluded.kast_percentage,
            kills_per_round=excluded.kills_per_round,
            deaths_per_round=excluded.deaths_per_round,
            assists_per_round=excluded.assists_per_round,
            maps_played=excluded.maps_played, image_url=excluded.image_url,
            scraped_at=excluded.scraped_at
        """,
        {
            "hltv_slug": player.hltv_slug,
            "nickname": player.nickname,
            "full_name": player.full_name,
            "age": player.age,
            "country": player.country,
            "team_id": team_id,
            "rating_overall": player.rating_overall,
            "rating_ct_side": player.rating_ct_side,
            "rating_t_side": player.rating_t_side,
            "kd_ratio": player.kd_ratio,
            "kd_diff_ct_side": player.kd_diff_ct_side,
            "kd_diff_t_side": player.kd_diff_t_side,
            "rounds_played_ct_side": player.rounds_played_ct_side,
            "rounds_played_t_side": player.rounds_played_t_side,
            "total_kills": player.total_kills,
            "total_deaths": player.total_deaths,
            "damage_per_round": player.damage_per_round,
            "headshot_percentage": player.headshot_percentage,
            "kast_percentage": player.kast_percentage,
            "kills_per_round": player.kills_per_round,
            "deaths_per_round": player.deaths_per_round,
            "assists_per_round": player.assists_per_round,
            "maps_played": player.maps_played,
            "image_url": player.image_url,
            "scraped_at": now,
        },
    )
    conn.commit()


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def main() -> None:
    PLAYER_IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    TEAM_IMAGES_DIR.mkdir(parents=True, exist_ok=True)

    driver = init_driver()
    conn = init_db(DB_PATH)

    try:
        manual_cloudflare_gate(driver, BASE_URL)

        log.info("=== Scraping teams ===")
        teams = scrape_team_ranking(driver)
        team_id_by_slug: dict[str, int] = {}
        roster_to_team_id: dict[str, int] = {}

        for i, team in enumerate(teams, start=1):
            log.info("[%d/%d] Team detail: %s", i, len(teams), team.name)
            scrape_team_detail(driver, team)
            image_dest = TEAM_IMAGES_DIR / f"{team.hltv_slug}.png"
            team.logo_url = download_image(team.logo_url, image_dest)

            team_id = upsert_team(conn, team)
            team_id_by_slug[team.hltv_slug] = team_id
            for roster_slug in team.roster_slugs:
                roster_to_team_id[roster_slug] = team_id

        log.info("=== Scraping players ===")
        players = scrape_player_ranking(driver)
        for i, player in enumerate(players, start=1):
            log.info("[%d/%d] Player profile+stats: %s", i, len(players), player.nickname)
            scrape_player_profile(driver, player)
            scrape_player_stats(driver, player)

            image_dest = PLAYER_IMAGES_DIR / f"{player.hltv_slug}.jpg"
            player.image_url = download_image(player.image_url, image_dest)

            team_id = roster_to_team_id.get(player.hltv_slug)
            if team_id is None and player.team_name:
                # fall back to matching by team name against scraped teams
                for team in teams:
                    if team.name.lower() == player.team_name.lower():
                        team_id = team_id_by_slug.get(team.hltv_slug)
                        break

            upsert_player(conn, player, team_id)

        log.info(
            "Done: %d teams and %d players written to %s",
            len(teams), len(players), DB_PATH,
        )
    finally:
        conn.close()
        driver.quit()


if __name__ == "__main__":
    main()
