"""Unit checks for audio release-readiness rules (not listening approval)."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("solarit_audio_pipeline", ROOT / "tools" / "audio_pipeline.py")
PIPELINE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(PIPELINE)


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

    def test_music_format_is_not_silently_relaxed(self):
        blockers = PIPELINE.release_blockers(self.approved_asset(), {"sample_rate": 44_100, "channels": 1})
        self.assertTrue(any("expected 48000 Hz" in issue for issue in blockers))
        self.assertTrue(any("music must be stereo" in issue for issue in blockers))

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

    def test_curated_sfx_have_explicit_cc0_provenance_and_pending_review(self):
        catalog = PIPELINE.read_json(PIPELINE.SFX_CATALOG)
        clips = [clip for variants in catalog["cues"].values() for clip in variants]
        self.assertGreaterEqual(len(clips), 10)
        for clip in clips:
            self.assertTrue(clip["path"].startswith("res://assets/audio/sfx/kenney/"))
            self.assertEqual(clip["asset_status"], "candidate")
            self.assertEqual(clip["human_listening_approval"], "pending")
            self.assertEqual(clip["license"]["status"], "cleared")
            self.assertIs(clip["license"]["commercial_use"], True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
