"""Unit checks for audio release-readiness rules (not listening approval)."""
import importlib.util
from pathlib import Path
import json
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("solarit_audio_pipeline", ROOT / "tools" / "audio_pipeline.py")
PIPELINE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(PIPELINE)
REVIEW_SPEC = importlib.util.spec_from_file_location("solarit_audio_review", ROOT / "tools" / "build_audio_review.py")
REVIEW = importlib.util.module_from_spec(REVIEW_SPEC)
assert REVIEW_SPEC.loader is not None
REVIEW_SPEC.loader.exec_module(REVIEW)


class AudioReleaseGateTests(unittest.TestCase):
    def approved_asset(self):
        return {
            "id": "test_asset", "kind": "music", "asset_status": "approved", "approval": "approved",
            "license": {"name": "CC0 1.0", "status": "cleared", "commercial_use": True},
            "listening_review": {
                "reviewer": "reviewer", "review_date": "2026-10-13", "at_30_seconds": "pass",
                "at_5_minutes": "pass", "in_match": "pass",
            },
        }

    def test_fully_cleared_music_has_no_policy_blocker(self):
        self.assertEqual(PIPELINE.release_blockers(self.approved_asset(), {"sample_rate": 48_000, "channels": 2}), [])

    def test_placeholder_pending_and_unknown_rights_block(self):
        asset = self.approved_asset()
        asset.update(asset_status="placeholder", approval="pending", license={"status": "unknown"})
        blockers = PIPELINE.release_blockers(asset, {"sample_rate": 48_000, "channels": 2})
        self.assertTrue(any("asset_status=placeholder" in issue for issue in blockers))
        self.assertTrue(any("approval=pending" in issue for issue in blockers))
        self.assertTrue(any("license" in issue for issue in blockers))

    def test_incomplete_human_review_blocks_even_when_technical_format_is_valid(self):
        asset = self.approved_asset()
        asset["listening_review"].pop("in_match")
        blockers = PIPELINE.release_blockers(asset, {"sample_rate": 48_000, "channels": 2})
        self.assertTrue(any("human listening review is incomplete" in issue for issue in blockers))

    def test_voice_review_uses_speech_criteria_instead_of_music_duration_checks(self):
        asset = self.approved_asset()
        asset.update(kind="voice", listening_review={
            "reviewer": "reviewer", "review_date": "2026-10-16", "clarity": "pass",
            "pronunciation": "pass", "faction_identity": "pass", "repeat_test": "pass",
            "in_match": "pass",
        })
        self.assertEqual(PIPELINE.release_blockers(asset, {"sample_rate": 48_000, "channels": 1}), [])
        asset["listening_review"].pop("pronunciation")
        blockers = PIPELINE.release_blockers(asset, {"sample_rate": 48_000, "channels": 1})
        self.assertTrue(any("human listening review is incomplete" in issue for issue in blockers))

    def test_sfx_review_requires_event_fit_and_mix_check(self):
        asset = self.approved_asset()
        asset.update(kind="sfx", listening_review={
            "reviewer": "reviewer", "review_date": "2026-10-16", "function_fit": "pass",
            "mix_level": "pass", "in_match": "pass",
        })
        self.assertEqual(PIPELINE.release_blockers(asset, {"sample_rate": 48_000, "channels": 1}), [])
        asset["listening_review"].pop("mix_level")
        blockers = PIPELINE.release_blockers(asset, {"sample_rate": 48_000, "channels": 1})
        self.assertTrue(any("human listening review is incomplete" in issue for issue in blockers))

    def test_music_format_is_not_silently_relaxed(self):
        blockers = PIPELINE.release_blockers(self.approved_asset(), {"sample_rate": 44_100, "channels": 1})
        self.assertTrue(any("expected 48000 Hz" in issue for issue in blockers))
        self.assertTrue(any("music must be stereo" in issue for issue in blockers))

    def test_current_catalog_license_wins_over_stale_manifest_license(self):
        row = {"id": "first_signal", "sha256": "same-bytes", "kind": "music", "faction": "global",
               "state": "title", "playback": {"loop_start_seconds": 0.0, "loop_end_seconds": 148.4},
               "license": {"name": "CC0 1.0", "status": "cleared",
                                                     "commercial_use": True, "attribution": "Bobjt"}}
        old = {"license": {"name": "CC0 1.0", "status": "cleared",
                            "commercial_use": True, "attribution": "vitalezzz"},
               "sha256": "same-bytes", "playback_signature": PIPELINE.playback_signature(row),
               "listening_review": {"reviewer": "reviewer", "review_date": "2026-10-13"}}
        merged = PIPELINE.preserve_manifest_review_data(row, old, current_sha256="same-bytes",
                                                          current_playback_signature=PIPELINE.playback_signature(row))
        self.assertEqual(merged["license"]["attribution"], "Bobjt")
        self.assertEqual(merged["listening_review"], old["listening_review"])

    def test_playback_change_invalidates_listening_evidence_even_when_audio_bytes_match(self):
        row = {"id": "factory_loop", "kind": "music", "faction": "forge", "state": "calm_a",
               "playback": {"bus": "Music", "loop_start_seconds": 0.0, "loop_end_seconds": 120.0}}
        reviewed = {"sha256": "same-bytes", "playback_signature": PIPELINE.playback_signature(row),
                    "listening_review": {"reviewer": "human", "review_date": "2026-10-16", "in_match": "pass"}}
        changed = dict(row)
        changed["playback"] = {**row["playback"], "gain": 0.45}
        preserved = PIPELINE.preserve_manifest_review_data(
            changed, reviewed, current_sha256="same-bytes",
            current_playback_signature=PIPELINE.playback_signature(changed))
        self.assertNotIn("listening_review", preserved)

    def test_playback_change_also_invalidates_provisional_development_review(self):
        row = {"id": "factory_loop", "kind": "music", "faction": "forge", "state": "calm_a",
               "playback": {"loop_start_seconds": 0.0}}
        signature = PIPELINE.playback_signature(row)
        old = {"sha256": "same-bytes", "playback_signature": signature,
               "development_listening_review": {"status": "provisional", "reviewer": "owner"}}
        preserved = PIPELINE.preserve_manifest_review_data(
            dict(row), old, current_sha256="same-bytes", current_playback_signature=signature)
        self.assertEqual(preserved["development_listening_review"]["status"], "provisional")
        changed = {**row, "playback": {"loop_start_seconds": 0.0, "gain": 0.5}}
        invalidated = PIPELINE.preserve_manifest_review_data(
            dict(changed), old, current_sha256="same-bytes",
            current_playback_signature=PIPELINE.playback_signature(changed))
        self.assertNotIn("development_listening_review", invalidated)

    def test_release_gate_ignores_pending_unreferenced_assets_but_keeps_active_pending_blockers(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "active.ogg").write_bytes(b"active")
            active_catalog = {"id": "active_music", "kind": "music", "faction": "forge", "state": "calm_a",
                              "catalog_path": "res://active.ogg", "asset_status": "candidate", "approval": "pending",
                              "release_required": True, "playback": {}, "license": {"status": "unknown"}}
            active_manifest = {**active_catalog, "sha256": "active-hash",
                               "playback_signature": PIPELINE.playback_signature(active_catalog)}
            inactive_manifest = {"id": "archived_candidate", "kind": "sfx", "catalog_path": "res://not-shipped.ogg",
                                 "release_required": False, "asset_status": "placeholder", "approval": "pending"}
            manifest_path = root / "audio_manifest.json"
            manifest_path.write_text(json.dumps({"assets": [active_manifest, inactive_manifest]}), encoding="utf-8")
            with patch.object(PIPELINE, "ROOT", root), patch.object(PIPELINE, "MANIFEST", manifest_path), \
                    patch.object(PIPELINE, "catalog_rows", return_value=[active_catalog]), \
                    patch.object(PIPELINE, "catalog_coverage_blockers", return_value=[]), \
                    patch.object(PIPELINE, "probe", return_value={"sample_rate": 48_000, "channels": 2}), \
                    patch.object(PIPELINE, "sha256", return_value="active-hash"):
                errors = PIPELINE.check_manifest(strict=True)
            self.assertTrue(any("active_music" in issue for issue in errors))
            self.assertFalse(any("archived_candidate" in issue for issue in errors))

    def test_playback_signature_covers_runtime_mix_and_review_criteria(self):
        row = {"kind": "music", "faction": "forge", "state": "battle_high", "playback": {}}
        original = PIPELINE.playback_signature(row)
        row["state"] = "stinger_victory"
        self.assertNotEqual(original, PIPELINE.playback_signature(row))

    def test_changed_audio_does_not_inherit_old_listening_evidence(self):
        row = {"id": "first_signal", "sha256": "new-audio"}
        old = {"sha256": "old-audio", "listening_review": {
            "reviewer": "reviewer", "review_date": "2026-10-13", "at_30_seconds": "pass",
            "at_5_minutes": "pass", "in_match": "pass",
        }}
        merged = PIPELINE.preserve_manifest_review_data(row, old, current_sha256="new-audio")
        self.assertNotIn("listening_review", merged)

    def test_uncatalogued_asset_can_keep_verified_manifest_license(self):
        old_license = {"name": "CC0 1.0", "status": "cleared", "commercial_use": True}
        merged = PIPELINE.preserve_manifest_review_data({"id": "legacy_asset"}, {"license": old_license})
        self.assertEqual(merged["license"], old_license)

    def test_music_catalog_requires_full_state_and_stinger_coverage(self):
        faction_states = {"calm_a": [], "calm_b": [], "contact": [], "battle_low": [], "battle_high": [], "critical": []}
        complete = {"factions": {faction: {"tracks": faction_states} for faction in ("forge", "drift", "lumen")},
                    "global_stingers": {name: {} for name in ("mission_start", "objective_complete", "major_alert", "victory", "defeat")}}
        self.assertEqual(PIPELINE.music_coverage_blockers(complete), [])
        incomplete = {"factions": {faction: {"tracks": {"calm_a": []}} for faction in ("forge", "drift", "lumen")},
                      "global_stingers": {}}
        blockers = PIPELINE.music_coverage_blockers(incomplete)
        self.assertTrue(any("forge/critical" in issue for issue in blockers))
        self.assertTrue(any("global stinger victory" in issue for issue in blockers))

    def test_faction_calm_b_tracks_are_distinct_and_unmetered_metadata_is_explicit(self):
        catalog = PIPELINE.read_json(PIPELINE.MUSIC_CATALOG)
        calm_b = {faction: rows[0] for faction, data in catalog["factions"].items()
                  for rows in [data["tracks"]["calm_b"]]}
        self.assertEqual(len({track["path"] for track in calm_b.values()}), len(calm_b))
        wanderpakt = calm_b["drift"]
        self.assertEqual(wanderpakt["source"]["author"], "TinyWorlds")
        self.assertTrue(wanderpakt["unmetered"])
        self.assertEqual(wanderpakt["bpm"], 0)
        self.assertEqual(wanderpakt["asset_status"], "candidate")
        self.assertEqual(wanderpakt["human_listening_approval"], "pending")
        battle_variants = {faction: data["tracks"]["battle_high"] for faction, data in catalog["factions"].items()}
        self.assertEqual(len(battle_variants["forge"]), 2)
        self.assertEqual(len(battle_variants["drift"]), 2)
        self.assertEqual(len(battle_variants["lumen"]), 3)
        kobalt_bombastic = battle_variants["forge"][1]
        wanderpakt_bombastic = battle_variants["drift"][1]
        self.assertEqual(kobalt_bombastic["source"]["author"], "cynicmusic / pixelsphere")
        self.assertEqual(wanderpakt_bombastic["source"]["author"], "Tarush Singhal")
        for track in (kobalt_bombastic, wanderpakt_bombastic):
            self.assertTrue(track["unmetered"])
            self.assertEqual(track["bpm"], 0)
            self.assertEqual(track["asset_status"], "candidate")
            self.assertEqual(track["human_listening_approval"], "pending")
        space_battle = battle_variants["lumen"][2]
        self.assertEqual(space_battle["source"]["author"], "MintoDog")
        self.assertEqual(space_battle["source"]["url"], "https://opengameart.org/content/space-battle")
        self.assertTrue(space_battle["unmetered"])
        self.assertEqual(space_battle["bpm"], 0)
        self.assertEqual(space_battle["asset_status"], "candidate")
        self.assertEqual(space_battle["human_listening_approval"], "pending")

    def test_curated_sfx_have_explicit_cc0_provenance_and_pending_review(self):
        catalog = PIPELINE.read_json(PIPELINE.SFX_CATALOG)
        clips = [clip for variants in catalog["cues"].values() for clip in variants]
        self.assertGreaterEqual(len(clips), 10)
        for clip in clips:
            if clip["id"] == "oga_bart_refinery_ambience":
                self.assertEqual(clip["path"], "res://assets/audio/sfx/industrial/refinery_ambience.ogg")
                self.assertEqual(clip["author"], "bart")
                self.assertEqual(clip["source_url"], "https://opengameart.org/content/steam-boiler-sound-loop")
                self.assertEqual(clip["source"], "Steam boiler sound loop")
                self.assertEqual(clip["license"]["name"], "CC0 1.0")
                self.assertTrue((ROOT / clip["path"].removeprefix("res://")).is_file())
                self.assertEqual(clip["asset_status"], "candidate")
                self.assertEqual(clip["human_listening_approval"], "pending")
                self.assertEqual(clip["license"]["status"], "cleared")
                self.assertIs(clip["license"]["commercial_use"], True)
                continue
            self.assertTrue(clip["path"].startswith("res://assets/audio/sfx/kenney/"))
            self.assertEqual(clip["asset_status"], "candidate")
            self.assertEqual(clip["human_listening_approval"], "pending")
            self.assertEqual(clip["license"]["status"], "cleared")
            self.assertIs(clip["license"]["commercial_use"], True)

    def test_listening_board_includes_every_faction_and_system_voice(self):
        voices = PIPELINE.read_json(PIPELINE.VOICE_CATALOG)
        rows = REVIEW.voice_rows(voices)
        self.assertEqual(len(rows), 124)
        self.assertEqual(sum(1 for faction, _ in rows if faction == "neutral"), 22)
        self.assertTrue(all(line.get("asset") for _, line in rows))
        REVIEW.build()
        page = (ROOT / "test-output/audio-review/index.html").read_text(encoding="utf-8")
        self.assertEqual(page.count("System ·"), 22)
        self.assertIn("Space Graveyard", page)
        self.assertIn("Noisy Battle", page)
        self.assertIn("Dark Sci-Fi · Urgent", page)
        self.assertIn("Dark Sci-Fi · Title", page)
        self.assertIn("Epic Fight Theme / Boss Battle", page)
        self.assertIn("Battle Theme A", page)
        self.assertIn("Space Battle", page)
        self.assertIn("MintoDog", page)
        self.assertIn("Outer Space · Battle Intro", page)
        self.assertIn("Outer Space · Battle Loop", page)
        self.assertIn("CC-BY 4.0", page)
        self.assertIn("Leonardo Paz", page)
        self.assertIn("nicht im Spiel aktiv", page)
        self.assertEqual(page.count("<h3>CC0-Sci-Fi-SFX"), 60)
        self.assertEqual(len(list((ROOT / "test-output/audio-review/sfx_60_cc0").glob("sfx_*.ogg"))), 60)
        self.assertIn("Generator Loop · Raffinerie/Kraftwerk", page)
        self.assertIn("Long Sci-Fi Sting · Alarm/Intro", page)
        self.assertIn("opengameart.org/content/steam-boiler-sound-loop", page)
        self.assertIn("opengameart.org/content/long-sci-fi-sting", page)
        self.assertIn("Engine Sound 1 · Fahrzeugmotor", page)
        self.assertIn("Engine Sound 2 · Fahrzeugmotor", page)
        self.assertIn("opengameart.org/content/engine-sounds2", page)
        self.assertIn("Musik nach 30 Sekunden, bei fünf Minuten und im Match", page)
        self.assertIn("Verständlichkeit, Aussprache, Fraktionscharakter", page)
        self.assertIn("Ereignispassung, Lautheit und Match-Mix", page)
        self.assertEqual(len(list((ROOT / "test-output/audio-review/sfx_alternatives").iterdir())), 4)


if __name__ == "__main__":
    unittest.main(verbosity=2)
