#!/usr/bin/env python3
"""Small dependency-free presence and personal/global leaderboard API."""
from __future__ import annotations

import hmac
import hashlib
import ipaddress
import json
import os
import re
import secrets
import socket
import sqlite3
import time
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlparse
from urllib.request import Request, urlopen

DB_PATH = Path(os.environ.get("SOLARIT_DB", "/var/lib/solarit-api/solarit.sqlite3"))
ADMIN_TOKEN = os.environ.get("SOLARIT_ADMIN_TOKEN", "")
HOST = os.environ.get("SOLARIT_BIND", "127.0.0.1")
PORT = int(os.environ.get("SOLARIT_PORT", "8765"))
ONLINE_SECONDS = 120
LOBBY_SECONDS = 75
MAX_LOBBIES = 64
MAX_BODY = 64 * 1024
PROFILE_RE = re.compile(r"^[A-Za-z0-9_-]{8,64}$")
RUN_RE = re.compile(r"^[A-Za-z0-9:_-]{1,96}$")
MISSION_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
GAME_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{1,63}$")
DEFAULT_GAME_ID = "solarit-randsektor-07"
TRUSTED_PROXY_EDGE = os.environ.get("SOLARIT_PROXY_EDGE", "192.168.178.148")
PUBLIC_ADDRESS_HOST = os.environ.get("SOLARIT_PUBLIC_ADDRESS_HOST", "api.dl-home.de")
PUBLIC_DNS_JSON_URLS = (
    "https://cloudflare-dns.com/dns-query",
    "https://dns.google/resolve",
)
ALLOWED_GAMES = {
    item.strip() for item in os.environ.get("SOLARIT_ALLOWED_GAMES", DEFAULT_GAME_ID).split(",")
    if GAME_RE.fullmatch(item.strip())
}
ALLOWED_GAMES.add(DEFAULT_GAME_ID)


def _create_v2_tables(db: sqlite3.Connection) -> None:
    db.execute("""CREATE TABLE players (
        game_id TEXT NOT NULL,
        profile_id TEXT NOT NULL,
        nickname TEXT NOT NULL,
        first_seen INTEGER NOT NULL,
        last_seen INTEGER NOT NULL,
        game_version TEXT NOT NULL DEFAULT '',
        PRIMARY KEY(game_id, profile_id)
    )""")
    db.execute("""CREATE TABLE sessions (
        game_id TEXT NOT NULL,
        client_id TEXT NOT NULL,
        profile_id TEXT NOT NULL,
        last_seen INTEGER NOT NULL,
        playing INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(game_id, client_id),
        FOREIGN KEY(game_id, profile_id) REFERENCES players(game_id, profile_id) ON DELETE CASCADE
    )""")
    db.execute("CREATE INDEX sessions_last_seen ON sessions(game_id, last_seen)")
    db.execute("""CREATE TABLE results (
        game_id TEXT NOT NULL,
        run_id TEXT NOT NULL,
        profile_id TEXT NOT NULL,
        nickname TEXT NOT NULL,
        mission_id TEXT NOT NULL,
        mission_name TEXT NOT NULL,
        score INTEGER NOT NULL CHECK(score >= 0),
        duration REAL NOT NULL CHECK(duration >= 0),
        difficulty TEXT NOT NULL DEFAULT '',
        faction TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        game_version TEXT NOT NULL DEFAULT '',
        PRIMARY KEY(game_id, run_id),
        FOREIGN KEY(game_id, profile_id) REFERENCES players(game_id, profile_id)
    )""")
    db.execute("CREATE INDEX results_mission_score ON results(game_id, mission_id, score DESC, duration ASC)")
    db.execute("CREATE INDEX results_profile ON results(game_id, profile_id, created_at DESC)")
    _create_lobby_table(db)


def _create_lobby_table(db: sqlite3.Connection) -> None:
    db.execute("""CREATE TABLE IF NOT EXISTS lobbies (
        game_id TEXT NOT NULL,
        lobby_id TEXT NOT NULL,
        host_profile_id TEXT NOT NULL,
        host_client_id TEXT NOT NULL,
        host_token_hash TEXT NOT NULL,
        nickname TEXT NOT NULL,
        mode TEXT NOT NULL,
        mission_id TEXT NOT NULL,
        mission_name TEXT NOT NULL,
        game_version TEXT NOT NULL DEFAULT '',
        public_address TEXT NOT NULL,
        port INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        last_seen INTEGER NOT NULL,
        PRIMARY KEY(game_id, lobby_id),
        UNIQUE(game_id, host_client_id)
    )""")
    columns = {row[1] for row in db.execute("PRAGMA table_info(lobbies)")}
    if "game_version" not in columns:
        db.execute("ALTER TABLE lobbies ADD COLUMN game_version TEXT NOT NULL DEFAULT ''")
    db.execute("CREATE INDEX IF NOT EXISTS lobbies_recent ON lobbies(game_id, last_seen DESC)")


def resolve_game_route(path: str, resources: set[str]) -> tuple[str, str] | None:
    legacy = {
        "/api/v1/heartbeat": "heartbeat",
        "/api/v1/results": "results",
        "/api/v1/highscores": "highscores",
        "/api/v1/me/results": "me/results",
    }
    if path in legacy:
        return DEFAULT_GAME_ID, legacy[path]
    prefix = "/api/v1/games/"
    if not path.startswith(prefix):
        return None
    parts = path[len(prefix):].split("/")
    resource = "/".join(parts[1:]) if len(parts) > 1 else ""
    game_id = parts[0] if parts else ""
    if not GAME_RE.fullmatch(game_id) or game_id not in ALLOWED_GAMES or resource not in resources:
        return None
    return game_id, resource


def connect_db() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(DB_PATH, timeout=5)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA journal_mode=WAL")
    db.execute("PRAGMA foreign_keys=ON")
    db.execute("PRAGMA foreign_keys=OFF")
    tables = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    if "players" not in tables:
        _create_v2_tables(db)
        db.execute("PRAGMA user_version=2")
    elif "game_id" not in {row[1] for row in db.execute("PRAGMA table_info(players)")}:
        # Preserve a v1 database by importing all existing data into SOLARIT's namespace.
        with db:
            db.execute("DROP INDEX IF EXISTS sessions_last_seen")
            db.execute("DROP INDEX IF EXISTS results_mission_score")
            db.execute("DROP INDEX IF EXISTS results_profile")
            if "results" in tables:
                db.execute("ALTER TABLE results RENAME TO results_v1")
            if "sessions" in tables:
                db.execute("ALTER TABLE sessions RENAME TO sessions_v1")
            db.execute("ALTER TABLE players RENAME TO players_v1")
            _create_v2_tables(db)
            db.execute("""INSERT INTO players(game_id,profile_id,nickname,first_seen,last_seen,game_version)
                SELECT ?,profile_id,nickname,first_seen,last_seen,game_version FROM players_v1""", (DEFAULT_GAME_ID,))
            if "sessions" in tables:
                db.execute("""INSERT INTO sessions(game_id,client_id,profile_id,last_seen,playing)
                    SELECT ?,client_id,profile_id,last_seen,playing FROM sessions_v1""", (DEFAULT_GAME_ID,))
            if "results" in tables:
                db.execute("""INSERT INTO results(game_id,run_id,profile_id,nickname,mission_id,mission_name,score,
                    duration,difficulty,faction,created_at,game_version)
                    SELECT ?,run_id,profile_id,nickname,mission_id,mission_name,score,duration,difficulty,faction,
                    created_at,game_version FROM results_v1""", (DEFAULT_GAME_ID,))
            db.execute("DROP TABLE IF EXISTS results_v1")
            db.execute("DROP TABLE IF EXISTS sessions_v1")
            db.execute("DROP TABLE players_v1")
            db.execute("PRAGMA user_version=2")
    else:
        db.execute("PRAGMA foreign_keys=ON")
    _create_lobby_table(db)
    db.execute("PRAGMA foreign_keys=ON")
    return db


@contextmanager
def database():
    db = connect_db()
    try:
        with db:
            yield db
    finally:
        db.close()


class Handler(BaseHTTPRequestHandler):
    server_version = "SolaritAPI/1.0"

    # Avoid collecting client IPs in default request logs.
    def log_message(self, _format: str, *_args: object) -> None:
        return

    def _json(self, status: int, value: object) -> None:
        raw = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(raw)

    def _body(self) -> dict | None:
        try:
            size = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return None
        if size < 1 or size > MAX_BODY:
            return None
        try:
            value = json.loads(self.rfile.read(size))
            return value if isinstance(value, dict) else None
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None

    def _admin(self) -> bool:
        supplied = self.headers.get("Authorization", "")
        expected = "Bearer " + ADMIN_TOKEN
        return bool(ADMIN_TOKEN) and hmac.compare_digest(supplied, expected)

    def _forwarded_client_ip(self) -> str:
        # Apache appends the real peer address to X-Forwarded-For. Nginx then
        # appends its trusted edge address, so use the item immediately before it.
        chain = [item.strip() for item in self.headers.get("X-Forwarded-For", "").split(",") if item.strip()]
        if len(chain) < 2 or chain[-1] != TRUSTED_PROXY_EDGE:
            return ""
        candidate = chain[-2]
        try:
            ipaddress.IPv4Address(candidate)
        except ValueError:
            return ""
        return candidate

    def _forwarded_public_ip(self) -> str:
        candidate = self._forwarded_client_ip()
        try:
            address = ipaddress.IPv4Address(candidate)
        except ValueError:
            return ""
        return candidate if address.is_global else ""

    def _system_ipv4_results(self):
        try:
            return socket.getaddrinfo(PUBLIC_ADDRESS_HOST, None, socket.AF_INET, socket.SOCK_STREAM)
        except OSError:
            return []

    def _service_public_ip(self) -> str:
        # A LAN client may reach this service through NAT loopback, so its
        # forwarded address is private. Some home DNS resolvers return the
        # reverse proxy's private address for the API hostname, so retry with
        # public DNS-over-HTTPS before giving up.
        for result in self._system_ipv4_results():
            candidate = result[4][0]
            try:
                address = ipaddress.IPv4Address(candidate)
            except ipaddress.AddressValueError:
                continue
            if address.is_global:
                return candidate

        query = urlencode({"name": PUBLIC_ADDRESS_HOST, "type": "A"})
        for resolver in PUBLIC_DNS_JSON_URLS:
            request = Request(
                resolver + "?" + query,
                headers={"Accept": "application/dns-json", "User-Agent": "SolaritAPI/1.0"},
            )
            try:
                with urlopen(request, timeout=2.0) as response:
                    payload = json.loads(response.read(8192).decode("utf-8"))
            except (OSError, UnicodeDecodeError, json.JSONDecodeError):
                continue
            if not isinstance(payload, dict):
                continue
            answers = payload.get("Answer", [])
            if not isinstance(answers, list):
                continue
            for answer in answers:
                if not isinstance(answer, dict) or answer.get("type") != 1:
                    continue
                candidate = str(answer.get("data", ""))
                try:
                    address = ipaddress.IPv4Address(candidate)
                except ipaddress.AddressValueError:
                    continue
                if address.is_global:
                    return candidate
        return ""

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._json(200, {"ok": True, "service": "solarit-api", "version": 1})
            return
        if parsed.path == "/api/v1/network/address":
            # Return the caller's public IPv4 only to that caller; do not persist or log it.
            client_address = self._forwarded_client_ip()
            address = self._forwarded_public_ip()
            if not address and client_address:
                try:
                    if ipaddress.IPv4Address(client_address).is_private:
                        address = self._service_public_ip()
                except ipaddress.AddressValueError:
                    pass
            if not address:
                self._json(503, {"ok": False, "error": "public_address_unavailable"})
                return
            self._json(200, {"ok": True, "address": address})
            return
        game_route = resolve_game_route(parsed.path, {"highscores", "me/results", "lobbies"})
        if game_route and game_route[1] == "lobbies":
            game_id, _ = game_route
            now = int(time.time())
            with database() as db:
                db.execute("DELETE FROM lobbies WHERE last_seen<?", (now - LOBBY_SECONDS,))
                rows = db.execute("""SELECT lobby_id,nickname,mode,mission_id AS mission,
                    mission_name,game_version,public_address AS address,port,created_at,last_seen
                    FROM lobbies WHERE game_id=? AND last_seen>=? ORDER BY created_at DESC LIMIT ?""",
                    (game_id, now - LOBBY_SECONDS, MAX_LOBBIES)).fetchall()
            lobbies = []
            for row in rows:
                lobby = dict(row)
                lobby["expires_in"] = max(0, LOBBY_SECONDS - (now - int(lobby["last_seen"])))
                lobbies.append(lobby)
            self._json(200, {"game_id": game_id, "lobbies": lobbies})
            return
        if game_route and game_route[1] == "highscores":
            game_id, _ = game_route
            mission = parse_qs(parsed.query).get("mission", [""])[0]
            if not MISSION_RE.fullmatch(mission):
                self._json(400, {"error": "invalid_mission"})
                return
            with database() as db:
                entries = db.execute("""
                    SELECT profile_id,nickname,mission_id AS mission,mission_name,score,
                           duration AS time,difficulty,faction,created_at AS date,run_id
                    FROM results WHERE game_id=? AND mission_id=?
                    ORDER BY score DESC,duration ASC,created_at ASC LIMIT 10
                """, (game_id, mission)).fetchall()
            self._json(200, {"game_id": game_id, "mission": mission, "entries": [dict(row) for row in entries]})
            return
        if game_route and game_route[1] == "me/results":
            game_id, _ = game_route
            profile = parse_qs(parsed.query).get("profile_id", [""])[0]
            if not PROFILE_RE.fullmatch(profile):
                self._json(400, {"error": "invalid_profile_id"})
                return
            with database() as db:
                entries = db.execute("""
                    SELECT mission_id AS mission,mission_name,score,duration AS time,
                           difficulty,faction,created_at AS date,run_id
                    FROM results WHERE game_id=? AND profile_id=? ORDER BY created_at DESC LIMIT 100
                """, (game_id, profile)).fetchall()
            self._json(200, {"game_id": game_id, "profile_id": profile, "entries": [dict(row) for row in entries]})
            return
        if parsed.path == "/api/v1/admin/players":
            if not self._admin():
                self._json(401, {"error": "unauthorized"})
                return
            now = int(time.time())
            filter_game = parse_qs(parsed.query).get("game_id", [""])[0]
            if filter_game and (not GAME_RE.fullmatch(filter_game) or filter_game not in ALLOWED_GAMES):
                self._json(400, {"error": "invalid_game_id"})
                return
            with database() as db:
                query = """
                    SELECT p.game_id,p.profile_id,p.nickname,p.first_seen,p.last_seen,p.game_version,
                           MAX(s.playing) AS playing
                    FROM players p JOIN sessions s ON s.profile_id=p.profile_id
                    WHERE s.game_id=p.game_id AND s.last_seen>=? AND s.playing=1
                """
                args: tuple = (now - ONLINE_SECONDS,)
                if filter_game:
                    query += " AND p.game_id=?"
                    args += (filter_game,)
                query += " GROUP BY p.game_id,p.profile_id ORDER BY p.last_seen DESC"
                rows = db.execute(query, args).fetchall()
            self._json(200, {"online_seconds": ONLINE_SECONDS, "players": [dict(row) for row in rows]})
            return
        if parsed.path == "/api/v1/admin/summary":
            if not self._admin():
                self._json(401, {"error": "unauthorized"})
                return
            with database() as db:
                players = db.execute("SELECT COUNT(*) FROM players").fetchone()[0]
                results = db.execute("SELECT COUNT(*) FROM results").fetchone()[0]
                games = db.execute("SELECT game_id,COUNT(DISTINCT profile_id) AS players_total FROM players GROUP BY game_id").fetchall()
            self._json(200, {"players_total": players, "results_total": results, "games": [dict(row) for row in games]})
            return
        self._json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        game_route = resolve_game_route(parsed.path, {"heartbeat", "results", "lobbies", "lobbies/heartbeat", "lobbies/close"})
        if game_route is None:
            self._json(404, {"error": "not_found_or_unknown_game"})
            return
        game_id, resource = game_route
        body = self._body()
        if body is None:
            self._json(400, {"error": "invalid_json_or_body_size"})
            return
        if body.get("game_id", game_id) != game_id:
            self._json(400, {"error": "game_id_mismatch"})
            return
        if resource == "lobbies":
            profile = body.get("profile_id", "")
            client = body.get("client_id", "")
            nickname = body.get("nickname", "")
            mode = body.get("mode", "")
            mission = body.get("mission", "")
            mission_name = body.get("mission_name", "")
            game_version = body.get("game_version", "")
            port = body.get("port", 0)
            public_address = self._forwarded_public_ip()
            if not isinstance(profile, str) or not PROFILE_RE.fullmatch(profile):
                self._json(400, {"error": "invalid_profile_id"}); return
            if not isinstance(client, str) or not PROFILE_RE.fullmatch(client):
                self._json(400, {"error": "invalid_client_id"}); return
            if not isinstance(nickname, str) or not 2 <= len(nickname.strip()) <= 20:
                self._json(400, {"error": "invalid_nickname"}); return
            if not isinstance(mode, str) or mode not in {"versus", "coop"}:
                self._json(400, {"error": "invalid_mode"}); return
            if not isinstance(mission, str) or not MISSION_RE.fullmatch(mission):
                self._json(400, {"error": "invalid_mission"}); return
            if not isinstance(mission_name, str) or not 1 <= len(mission_name.strip()) <= 80:
                self._json(400, {"error": "invalid_mission_name"}); return
            if not isinstance(game_version, str) or not re.fullmatch(r"\d+\.\d+\.\d+", game_version):
                self._json(400, {"error": "invalid_game_version"}); return
            if isinstance(port, bool) or not isinstance(port, int) or not 1024 <= port <= 65535:
                self._json(400, {"error": "invalid_port"}); return
            if not public_address:
                self._json(503, {"error": "public_address_unavailable"}); return
            now = int(time.time())
            lobby_id = secrets.token_urlsafe(12)
            lobby_token = secrets.token_urlsafe(32)
            token_hash = hashlib.sha256(lobby_token.encode("ascii")).hexdigest()
            with database() as db:
                db.execute("DELETE FROM lobbies WHERE last_seen<?", (now - LOBBY_SECONDS,))
                current = db.execute("SELECT lobby_id FROM lobbies WHERE game_id=? AND host_client_id=?", (game_id, client)).fetchone()
                if current:
                    db.execute("DELETE FROM lobbies WHERE game_id=? AND host_client_id=?", (game_id, client))
                count = db.execute("SELECT COUNT(*) FROM lobbies WHERE game_id=?", (game_id,)).fetchone()[0]
                if count >= MAX_LOBBIES:
                    self._json(503, {"error": "lobby_capacity_reached"}); return
                db.execute("""INSERT INTO lobbies(game_id,lobby_id,host_profile_id,host_client_id,host_token_hash,
                    nickname,mode,mission_id,mission_name,game_version,public_address,port,created_at,last_seen)
                    VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (game_id,lobby_id,profile,client,token_hash,nickname.strip(),mode,mission,
                     mission_name.strip()[:80],game_version,public_address,port,now,now))
            self._json(201, {"ok": True, "lobby_id": lobby_id, "lobby_token": lobby_token,
                             "address": public_address, "port": port, "expires_in": LOBBY_SECONDS})
            return
        if resource in {"lobbies/heartbeat", "lobbies/close"}:
            lobby_id = body.get("lobby_id", "")
            client = body.get("client_id", "")
            token = body.get("lobby_token", "")
            if not isinstance(lobby_id, str) or not re.fullmatch(r"[A-Za-z0-9_-]{8,64}", lobby_id):
                self._json(400, {"error": "invalid_lobby_id"}); return
            if not isinstance(client, str) or not PROFILE_RE.fullmatch(client):
                self._json(400, {"error": "invalid_client_id"}); return
            if not isinstance(token, str) or not 32 <= len(token) <= 128:
                self._json(400, {"error": "invalid_lobby_token"}); return
            token_hash = hashlib.sha256(token.encode("ascii", errors="ignore")).hexdigest()
            with database() as db:
                if resource == "lobbies/heartbeat":
                    cursor = db.execute("""UPDATE lobbies SET last_seen=? WHERE game_id=? AND lobby_id=?
                        AND host_client_id=? AND host_token_hash=?""",
                        (int(time.time()),game_id,lobby_id,client,token_hash))
                else:
                    cursor = db.execute("""DELETE FROM lobbies WHERE game_id=? AND lobby_id=?
                        AND host_client_id=? AND host_token_hash=?""",
                        (game_id,lobby_id,client,token_hash))
            if cursor.rowcount != 1:
                self._json(404, {"error": "lobby_not_found"}); return
            self._json(200, {"ok": True, "closed": resource == "lobbies/close"})
            return
        if resource == "heartbeat":
            profile = body.get("profile_id", "")
            client = body.get("client_id", "")
            nickname = body.get("nickname", "")
            version = body.get("game_version", "")
            playing = body.get("playing", False)
            if not isinstance(profile, str) or not PROFILE_RE.fullmatch(profile):
                self._json(400, {"error": "invalid_profile_id"})
                return
            if not isinstance(client, str) or not PROFILE_RE.fullmatch(client):
                self._json(400, {"error": "invalid_client_id"})
                return
            if not isinstance(nickname, str) or not 2 <= len(nickname.strip()) <= 20:
                self._json(400, {"error": "invalid_nickname"})
                return
            if not isinstance(playing, bool):
                self._json(400, {"error": "invalid_playing"})
                return
            now = int(time.time())
            with database() as db:
                db.execute("""INSERT INTO players(game_id,profile_id,nickname,first_seen,last_seen,game_version)
                    VALUES(?,?,?,?,?,?) ON CONFLICT(game_id,profile_id) DO UPDATE SET
                    nickname=excluded.nickname,last_seen=excluded.last_seen,game_version=excluded.game_version""",
                    (game_id, profile, nickname.strip(), now, now, str(version)[:24]))
                db.execute("""INSERT INTO sessions(game_id,client_id,profile_id,last_seen,playing) VALUES(?,?,?,?,?)
                    ON CONFLICT(game_id,client_id) DO UPDATE SET profile_id=excluded.profile_id,
                    last_seen=excluded.last_seen,playing=excluded.playing""",
                    (game_id, client, profile, now, int(playing)))
                db.execute("DELETE FROM sessions WHERE game_id=? AND last_seen<?", (game_id, now - 86400))
                count = db.execute("SELECT COUNT(DISTINCT profile_id) FROM sessions WHERE game_id=? AND last_seen>=? AND playing=1",
                                   (game_id, now - ONLINE_SECONDS)).fetchone()[0]
            self._json(200, {"ok": True, "game_id": game_id, "online_players": count, "online_seconds": ONLINE_SECONDS})
            return
        if resource == "results":
            profile, run_id = body.get("profile_id", ""), body.get("run_id", "")
            mission = body.get("mission", "")
            nickname = body.get("nickname", "")
            score, duration = body.get("score"), body.get("time")
            if not isinstance(profile, str) or not PROFILE_RE.fullmatch(profile):
                self._json(400, {"error": "invalid_profile_id"})
                return
            if not isinstance(run_id, str) or not RUN_RE.fullmatch(run_id):
                self._json(400, {"error": "invalid_run_id"})
                return
            if not isinstance(mission, str) or not MISSION_RE.fullmatch(mission):
                self._json(400, {"error": "invalid_mission"})
                return
            if not isinstance(nickname, str) or not 2 <= len(nickname.strip()) <= 20:
                self._json(400, {"error": "invalid_nickname"})
                return
            if isinstance(score, bool) or not isinstance(score, int) or not 0 <= score <= 100_000_000:
                self._json(400, {"error": "invalid_score"})
                return
            if isinstance(duration, bool) or not isinstance(duration, (int, float)) or not 0 <= duration <= 86400:
                self._json(400, {"error": "invalid_time"})
                return
            now = int(time.time())
            with connect_db() as db:
                player = db.execute("SELECT 1 FROM players WHERE game_id=? AND profile_id=?", (game_id, profile)).fetchone()
                if not player:
                    self._json(409, {"error": "heartbeat_required"})
                    return
                cursor = db.execute("""INSERT OR IGNORE INTO results
                    (game_id,run_id,profile_id,nickname,mission_id,mission_name,score,duration,difficulty,faction,created_at,game_version)
                    VALUES(?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (game_id, run_id, profile, nickname.strip(), mission,
                     str(body.get("mission_name", mission))[:120], score, float(duration),
                     str(body.get("difficulty", ""))[:32], str(body.get("faction", ""))[:64], now,
                     str(body.get("game_version", ""))[:24]))
                inserted = cursor.rowcount == 1
            self._json(201 if inserted else 200, {"ok": True, "stored": inserted, "game_id": game_id, "run_id": run_id})
            return
        self._json(404, {"error": "not_found"})


if __name__ == "__main__":
    connect_db().close()
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
