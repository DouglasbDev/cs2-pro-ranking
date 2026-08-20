"""
Imports manually-collected HLTV data from two CSVs into app_data.db.

Replaces the Selenium-based scraper (hltv_scraper.py) for this run: the
automated scrape hit unresolvable Cloudflare/corporate-antivirus blocks on
this machine, so the data was collected by hand into CSVs instead. This
script does the same "write into the schema" job the scraper would have
done, minus the browsing.

Expected input files (columns as produced manually from HLTV pages):

  teams_final.csv:
    name, country, maps_played, kd_diff, kd_ratio, rating_overall,
    wins, draws, losses, total_kills, total_deaths, rounds_played, roster
    (roster = comma-separated nicknames of the current lineup; used only
    to resolve player -> team_id, not stored as its own table)

  players_final.csv:
    nickname, country, team, maps_played, rating_overall, kd_ratio,
    kd_diff_both, rounds_played_both, rating_ct_side, kd_diff_ct_side,
    rounds_played_ct_side, rating_t_side, kd_diff_t_side,
    rounds_played_t_side, total_kills, total_deaths, damage_per_round,
    headshot_percentage, kast_percentage, kills_per_round,
    deaths_per_round, assists_per_round, has_full_detail
    (kd_diff_both / rounds_played_both have no matching column in the
    players table schema and are intentionally not imported; the detailed
    stat columns are blank/NULL whenever has_full_detail is false)

team_id resolution for each player tries, in order:
  1. The player's nickname found in some team's `roster` column (most
     reliable — this is how e.g. a player whose free-text `team` column
     says "MOUZGamerLegion" still correctly resolves to the "MOUZ" row,
     since "MOUZGamerLegion" doesn't match any team name but the player's
     nickname does appear in MOUZ's roster).
  2. Falling back to a case-insensitive exact match of the player's `team`
     column against a team's `name` column.
  3. NULL (logged) if neither resolves.

Usage:
    python import_data.py
    python import_data.py --players-csv path\\to\\players_final.csv --teams-csv path\\to\\teams_final.csv
"""

from __future__ import annotations

import argparse
import csv
import logging
import re
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

SCRIPT_DIR = Path(__file__).parent
OUTPUT_DIR = SCRIPT_DIR / "output"
DEFAULT_DB_PATH = OUTPUT_DIR / "assets" / "data" / "app_data.db"

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("import_data")

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


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

def slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.strip().lower()).strip("-")
    return slug or "unknown"


def to_int(value: Optional[str]) -> Optional[int]:
    if value is None:
        return None
    value = value.strip()
    if not value:
        return None
    return int(float(value))


def to_float(value: Optional[str]) -> Optional[float]:
    if value is None:
        return None
    value = value.strip()
    if not value:
        return None
    return float(value)


def to_str(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    value = value.strip()
    return value or None


def to_bool(value: Optional[str]) -> bool:
    return (value or "").strip().lower() == "true"


# --------------------------------------------------------------------------
# DB
# --------------------------------------------------------------------------

def init_db(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.executescript(SCHEMA_SQL)
    conn.commit()
    return conn


def insert_team(conn: sqlite3.Connection, row: dict) -> int:
    now = datetime.now(timezone.utc).isoformat()
    name = to_str(row.get("name"))
    if not name:
        raise ValueError(f"team row missing name: {row!r}")

    data = {
        "hltv_slug": slugify(name),
        "name": name,
        "country": to_str(row.get("country")),
        "maps_played": to_int(row.get("maps_played")),
        "wins": to_int(row.get("wins")),
        "draws": to_int(row.get("draws")),
        "losses": to_int(row.get("losses")),
        "total_kills": to_int(row.get("total_kills")),
        "total_deaths": to_int(row.get("total_deaths")),
        "rounds_played": to_int(row.get("rounds_played")),
        "kd_ratio": to_float(row.get("kd_ratio")),
        "kd_diff": to_int(row.get("kd_diff")),
        "rating_overall": to_float(row.get("rating_overall")),
        "logo_url": None,
        "scraped_at": now,
    }
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
            scraped_at=excluded.scraped_at
        """,
        data,
    )
    conn.commit()
    cur = conn.execute("SELECT id FROM teams WHERE hltv_slug = ?", (data["hltv_slug"],))
    return cur.fetchone()[0]


def insert_player(conn: sqlite3.Connection, row: dict, team_id: Optional[int]) -> None:
    now = datetime.now(timezone.utc).isoformat()
    nickname = to_str(row.get("nickname"))
    if not nickname:
        raise ValueError(f"player row missing nickname: {row!r}")

    data = {
        "hltv_slug": slugify(nickname),
        "nickname": nickname,
        "full_name": None,
        "age": None,
        "country": to_str(row.get("country")),
        "team_id": team_id,
        "rating_overall": to_float(row.get("rating_overall")),
        "rating_ct_side": to_float(row.get("rating_ct_side")),
        "rating_t_side": to_float(row.get("rating_t_side")),
        "kd_ratio": to_float(row.get("kd_ratio")),
        "kd_diff_ct_side": to_int(row.get("kd_diff_ct_side")),
        "kd_diff_t_side": to_int(row.get("kd_diff_t_side")),
        "rounds_played_ct_side": to_int(row.get("rounds_played_ct_side")),
        "rounds_played_t_side": to_int(row.get("rounds_played_t_side")),
        "total_kills": to_int(row.get("total_kills")),
        "total_deaths": to_int(row.get("total_deaths")),
        "damage_per_round": to_float(row.get("damage_per_round")),
        "headshot_percentage": to_float(row.get("headshot_percentage")),
        "kast_percentage": to_float(row.get("kast_percentage")),
        "kills_per_round": to_float(row.get("kills_per_round")),
        "deaths_per_round": to_float(row.get("deaths_per_round")),
        "assists_per_round": to_float(row.get("assists_per_round")),
        "maps_played": to_int(row.get("maps_played")),
        "image_url": None,
        "scraped_at": now,
    }
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
            nickname=excluded.nickname, country=excluded.country, team_id=excluded.team_id,
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
            maps_played=excluded.maps_played, scraped_at=excluded.scraped_at
        """,
        data,
    )
    conn.commit()


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--teams-csv", type=Path, default=SCRIPT_DIR / "teams_final.csv")
    parser.add_argument("--players-csv", type=Path, default=SCRIPT_DIR / "players_final.csv")
    parser.add_argument("--db-path", type=Path, default=DEFAULT_DB_PATH)
    args = parser.parse_args()

    if not args.teams_csv.exists():
        raise SystemExit(f"teams CSV not found: {args.teams_csv}")
    if not args.players_csv.exists():
        raise SystemExit(f"players CSV not found: {args.players_csv}")

    conn = init_db(args.db_path)

    # --- teams ---
    with args.teams_csv.open(newline="", encoding="utf-8-sig") as f:
        team_rows = [r for r in csv.DictReader(f) if to_str(r.get("name"))]

    team_id_by_slug: dict[str, int] = {}
    roster_to_team_id: dict[str, int] = {}
    team_id_by_name_lower: dict[str, int] = {}

    for row in team_rows:
        team_id = insert_team(conn, row)
        name = to_str(row["name"])
        slug = slugify(name)
        team_id_by_slug[slug] = team_id
        team_id_by_name_lower[name.lower()] = team_id

        roster_raw = to_str(row.get("roster")) or ""
        for nick in roster_raw.split(","):
            nick = nick.strip()
            if nick:
                roster_to_team_id[nick.lower()] = team_id

    log.info("Inserted/updated %d teams", len(team_rows))

    # --- players ---
    with args.players_csv.open(newline="", encoding="utf-8-sig") as f:
        player_rows = [r for r in csv.DictReader(f) if to_str(r.get("nickname"))]

    full_detail_count = 0
    unresolved_teams: list[str] = []

    for row in player_rows:
        nickname = to_str(row["nickname"])
        team_id = roster_to_team_id.get(nickname.lower())

        if team_id is None:
            team_name = to_str(row.get("team"))
            if team_name:
                team_id = team_id_by_name_lower.get(team_name.lower())
            if team_id is None:
                unresolved_teams.append(f"{nickname} (team={team_name!r})")

        insert_player(conn, row, team_id)
        if to_bool(row.get("has_full_detail")):
            full_detail_count += 1

    conn.close()

    log.info("Inserted/updated %d players", len(player_rows))
    if unresolved_teams:
        log.warning("%d player(s) had no resolvable team_id: %s", len(unresolved_teams), ", ".join(unresolved_teams))

    print()
    print("=== Import summary ===")
    print(f"Teams:                 {len(team_rows)}")
    print(f"Players:               {len(player_rows)}")
    print(f"  with has_full_detail: {full_detail_count}")
    print(f"  without:              {len(player_rows) - full_detail_count}")
    if unresolved_teams:
        print(f"Players with unresolved team_id: {len(unresolved_teams)}")
    print(f"Database written to: {args.db_path}")


if __name__ == "__main__":
    main()
