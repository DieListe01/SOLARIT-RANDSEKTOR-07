import json
import os
import tempfile
import threading
import unittest
from http.client import HTTPConnection
from pathlib import Path
from unittest.mock import patch

import solarit_api as api


class ApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        api.DB_PATH = Path(cls.temp.name) / "test.sqlite3"
        api.ADMIN_TOKEN = "test-admin-token"
        api.ALLOWED_GAMES.add("other-game")
        api.connect_db().close()
        cls.server = api.ThreadingHTTPServer(("127.0.0.1", 0), api.Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.port = cls.server.server_address[1]

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)
        cls.temp.cleanup()

    def request(self, method, path, body=None, headers=None):
        conn = HTTPConnection("127.0.0.1", self.port, timeout=3)
        payload = json.dumps(body).encode() if body is not None else None
        request_headers = {"Content-Type": "application/json"} if payload else {}
        request_headers.update(headers or {})
        conn.request(method, path, body=payload, headers=request_headers)
        response = conn.getresponse()
        data = json.loads(response.read() or b"{}")
        conn.close()
        return response.status, data

    def setUp(self):
        with api.database() as db:
            db.execute("DELETE FROM results")
            db.execute("DELETE FROM sessions")
            db.execute("DELETE FROM players")
            db.execute("DELETE FROM lobbies")

    def test_heartbeat_and_active_players(self):
        status, body = self.request("POST", "/api/v1/games/solarit-randsektor-07/heartbeat", {
            "profile_id": "profile-12345678", "client_id": "client-12345678",
            "nickname": "Dirk", "game_version": "0.36.6", "playing": True
        })
        self.assertEqual(status, 200)
        self.assertEqual(body["online_players"], 1)
        status, body = self.request("GET", "/api/v1/admin/players", headers={"Authorization": "Bearer test-admin-token"})
        self.assertEqual(status, 200)
        self.assertEqual(body["players"][0]["nickname"], "Dirk")
        self.request("POST", "/api/v1/games/solarit-randsektor-07/heartbeat", {
            "profile_id": "profile-12345678", "client_id": "client-12345678",
            "nickname": "Dirk", "playing": False
        })
        self.assertEqual(self.request("GET", "/api/v1/admin/players", headers={"Authorization": "Bearer test-admin-token"})[1]["players"], [])

    def test_result_is_per_profile_idempotent_and_ranked(self):
        heartbeat = {"profile_id": "profile-12345678", "client_id": "client-12345678", "nickname": "Dirk", "playing": True}
        self.request("POST", "/api/v1/games/solarit-randsektor-07/heartbeat", heartbeat)
        result = {"profile_id": "profile-12345678", "nickname": "Dirk", "run_id": "run-0001",
                  "mission": "veyra-01", "mission_name": "Veyra", "score": 1550, "time": 600,
                  "difficulty": "normal", "faction": "Forge", "game_version": "0.36.6"}
        self.assertEqual(self.request("POST", "/api/v1/games/solarit-randsektor-07/results", result)[0], 201)
        status, body = self.request("POST", "/api/v1/games/solarit-randsektor-07/results", result)
        self.assertEqual(status, 200)
        self.assertFalse(body["stored"])
        status, body = self.request("GET", "/api/v1/games/solarit-randsektor-07/highscores?mission=veyra-01")
        self.assertEqual(status, 200)
        self.assertEqual(body["entries"][0]["profile_id"], "profile-12345678")
        status, body = self.request("GET", "/api/v1/games/solarit-randsektor-07/me/results?profile_id=profile-12345678")
        self.assertEqual(status, 200)
        self.assertEqual(len(body["entries"]), 1)

    def test_admin_requires_token_and_invalid_score_is_rejected(self):
        self.assertEqual(self.request("GET", "/api/v1/admin/players")[0], 401)
        self.request("POST", "/api/v1/games/solarit-randsektor-07/heartbeat", {
            "profile_id": "profile-12345678", "client_id": "client-12345678", "nickname": "Dirk", "playing": True
        })
        status, body = self.request("POST", "/api/v1/games/solarit-randsektor-07/results", {
            "profile_id": "profile-12345678", "nickname": "Dirk", "run_id": "run-0002",
            "mission": "veyra-01", "score": -1, "time": 4
        })
        self.assertEqual(status, 400)
        self.assertEqual(body["error"], "invalid_score")

    def test_other_games_are_namespaced_and_legacy_alias_stays_solarit(self):
        shared_profile = "profile-12345678"
        for game_id, nickname, score in (("solarit-randsektor-07", "Dirk", 1550), ("other-game", "Pilot", 2200)):
            heartbeat = {"profile_id": shared_profile, "client_id": "client-12345678", "nickname": nickname, "playing": True}
            status, body = self.request("POST", f"/api/v1/games/{game_id}/heartbeat", heartbeat)
            self.assertEqual(status, 200)
            self.assertEqual(body["game_id"], game_id)
            result = {"profile_id": shared_profile, "nickname": nickname, "run_id": "shared-run",
                      "mission": "mission-01", "score": score, "time": 300}
            self.assertEqual(self.request("POST", f"/api/v1/games/{game_id}/results", result)[0], 201)
        solarit = self.request("GET", "/api/v1/games/solarit-randsektor-07/highscores?mission=mission-01")[1]
        other = self.request("GET", "/api/v1/games/other-game/highscores?mission=mission-01")[1]
        self.assertEqual(solarit["entries"][0]["nickname"], "Dirk")
        self.assertEqual(other["entries"][0]["nickname"], "Pilot")
        self.assertEqual(self.request("GET", "/api/v1/highscores?mission=mission-01")[1]["entries"][0]["nickname"], "Dirk")
        self.assertEqual(self.request("GET", "/api/v1/games/not-registered/highscores?mission=mission-01")[0], 404)

    def test_public_lobbies_are_short_lived_and_token_protected(self):
        path = "/api/v1/games/solarit-randsektor-07/lobbies"
        lobby = {
            "profile_id": "profile-12345678", "client_id": "client-12345678",
            "nickname": "Dirk", "mode": "versus", "mission": "veyra_basin",
            "mission_name": "Veyra-Becken", "game_version": "0.36.6", "port": 2456,
        }
        status, body = self.request("POST", path, lobby, headers={"X-Forwarded-For": "8.8.8.8"})
        self.assertEqual(status, 503)
        self.assertEqual(body["error"], "public_address_unavailable")

        status, body = self.request("POST", path, lobby, headers={"X-Forwarded-For": "8.8.8.8, 192.168.178.148"})
        self.assertEqual(status, 201)
        lobby_id = body["lobby_id"]
        token = body["lobby_token"]
        self.assertEqual(body["address"], "8.8.8.8")
        status, body = self.request("GET", path)
        self.assertEqual(status, 200)
        self.assertEqual(len(body["lobbies"]), 1)
        listed = body["lobbies"][0]
        self.assertEqual(listed["address"], "8.8.8.8")
        self.assertEqual(listed["game_version"], "0.36.6")
        self.assertGreaterEqual(listed["expires_in"], 0)
        self.assertLessEqual(listed["expires_in"], api.LOBBY_SECONDS)
        self.assertNotIn("host_profile_id", listed)
        self.assertNotIn("host_client_id", listed)
        self.assertNotIn("host_token_hash", listed)

        heartbeat_path = path + "/heartbeat"
        auth = {"lobby_id": lobby_id, "lobby_token": token, "client_id": lobby["client_id"]}
        self.assertEqual(self.request("POST", heartbeat_path, {**auth, "lobby_token": "x" * 40})[0], 404)
        self.assertEqual(self.request("POST", heartbeat_path, auth)[0], 200)
        with api.database() as db:
            db.execute("UPDATE lobbies SET last_seen=? WHERE lobby_id=?", (int(api.time.time()) - api.LOBBY_SECONDS - 1, lobby_id))
        self.assertEqual(self.request("GET", path)[1]["lobbies"], [])
        status, body = self.request("POST", path, lobby, headers={"X-Forwarded-For": "8.8.4.4, 192.168.178.148"})
        self.assertEqual(status, 201)
        close = {"lobby_id": body["lobby_id"], "lobby_token": body["lobby_token"], "client_id": lobby["client_id"]}
        self.assertEqual(self.request("POST", path + "/close", close)[0], 200)
        self.assertEqual(self.request("GET", path)[1]["lobbies"], [])

    def test_public_lobby_rejects_missing_or_invalid_game_version(self):
        path = "/api/v1/games/solarit-randsektor-07/lobbies"
        lobby = {
            "profile_id": "profile-12345678", "client_id": "client-12345678",
            "nickname": "Dirk", "mode": "versus", "mission": "veyra_basin",
            "mission_name": "Veyra-Becken", "port": 2456,
        }
        for version in (None, "0.36.6-beta", "latest"):
            payload = dict(lobby)
            if version is not None:
                payload["game_version"] = version
            status, body = self.request("POST", path, payload, headers={"X-Forwarded-For": "8.8.8.8, 192.168.178.148"})
            self.assertEqual(status, 400)
            self.assertEqual(body["error"], "invalid_game_version")

    def test_network_address_returns_only_trusted_proxy_public_ipv4(self):
        path = "/api/v1/network/address"
        status, body = self.request("GET", path)
        self.assertEqual(status, 503)
        self.assertEqual(body["error"], "public_address_unavailable")

        status, body = self.request("GET", path, headers={"X-Forwarded-For": "8.8.8.8"})
        self.assertEqual(status, 503)
        self.assertEqual(body["error"], "public_address_unavailable")

        with patch.object(api.Handler, "_service_public_ip", return_value="8.8.8.8"):
            status, body = self.request("GET", path, headers={"X-Forwarded-For": "192.168.178.50, 192.168.178.148"})
        self.assertEqual(status, 200)
        self.assertEqual(body, {"ok": True, "address": "8.8.8.8"})

        status, body = self.request("GET", path, headers={"X-Forwarded-For": "8.8.8.8, 192.168.178.148"})
        self.assertEqual(status, 200)
        self.assertEqual(body, {"ok": True, "address": "8.8.8.8"})

    def test_lan_public_address_fallback_uses_public_dns_when_split_dns_is_private(self):
        class FakeResponse:
            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def read(self, _limit):
                return json.dumps({"Answer": [
                    {"name": "api.dl-home.de", "type": 1, "data": "192.168.178.148"},
                    {"name": "api.dl-home.de", "type": 1, "data": "8.8.8.8"},
                ]}).encode("utf-8")

        handler = object.__new__(api.Handler)
        with patch.object(api.socket, "getaddrinfo", return_value=[
            (None, None, 0, "", ("192.168.178.148", 0)),
        ]), patch.object(api, "urlopen", return_value=FakeResponse()):
            self.assertEqual(handler._service_public_ip(), "8.8.8.8")

    def test_legacy_database_migrates_into_solarit_namespace(self):
        path = Path(self.temp.name) / "legacy.sqlite3"
        previous_path = api.DB_PATH
        try:
            api.DB_PATH = path
            db = __import__("sqlite3").connect(path)
            db.executescript("""
                CREATE TABLE players(profile_id TEXT PRIMARY KEY,nickname TEXT NOT NULL,first_seen INTEGER NOT NULL,last_seen INTEGER NOT NULL,game_version TEXT NOT NULL DEFAULT '');
                CREATE TABLE sessions(client_id TEXT PRIMARY KEY,profile_id TEXT NOT NULL REFERENCES players(profile_id),last_seen INTEGER NOT NULL,playing INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE results(run_id TEXT PRIMARY KEY,profile_id TEXT NOT NULL REFERENCES players(profile_id),nickname TEXT NOT NULL,mission_id TEXT NOT NULL,mission_name TEXT NOT NULL,score INTEGER NOT NULL,duration REAL NOT NULL,difficulty TEXT NOT NULL DEFAULT '',faction TEXT NOT NULL DEFAULT '',created_at INTEGER NOT NULL,game_version TEXT NOT NULL DEFAULT '');
                CREATE INDEX sessions_last_seen ON sessions(last_seen);
                CREATE INDEX results_mission_score ON results(mission_id,score DESC,duration ASC);
                CREATE INDEX results_profile ON results(profile_id,created_at DESC);
                INSERT INTO players VALUES('profile-12345678','Dirk',1,2,'0.36.7');
                INSERT INTO sessions VALUES('client-12345678','profile-12345678',2,1);
                INSERT INTO results VALUES('run-0001','profile-12345678','Dirk','veyra-01','Veyra',1500,300,'normal','Forge',2,'0.36.7');
            """)
            db.close()
            migrated = api.connect_db()
            self.assertEqual(migrated.execute("PRAGMA user_version").fetchone()[0], 2)
            self.assertEqual(migrated.execute("SELECT game_id FROM results WHERE run_id='run-0001'").fetchone()[0], api.DEFAULT_GAME_ID)
            self.assertEqual(migrated.execute("SELECT COUNT(*) FROM sessions WHERE game_id=?", (api.DEFAULT_GAME_ID,)).fetchone()[0], 1)
            migrated.close()
        finally:
            api.DB_PATH = previous_path

    def test_installation_defers_tls_and_preserves_other_nginx_sites(self):
        server_dir = Path(__file__).parent
        installer = (server_dir / "install-container.sh").read_text(encoding="utf-8")
        https_setup = (server_dir / "enable-https.sh").read_text(encoding="utf-8")
        http_site = (server_dir / "nginx-api.conf.template").read_text(encoding="utf-8")
        self.assertNotIn("certbot ", installer)
        self.assertNotIn("sites-enabled/default", installer)
        self.assertIn('[[ "$confirmation" == "JA" ]]', https_setup)
        self.assertIn("certbot certonly --webroot", https_setup)
        self.assertIn("location / { return 503; }", http_site)


if __name__ == "__main__":
    unittest.main()
