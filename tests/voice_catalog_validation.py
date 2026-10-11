"""Validate the voice catalogue and fail on stale/missing recordings."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "assets/audio/voice/voice_catalog.json"
REQUIRED_FACTIONS = {"forge", "drift", "lumen"}
REQUIRED_EVENTS = {
    "select": 4, "move": 4, "attack": 4, "damage": 3, "critical": 2,
    "success": 2, "harvester_select": 3, "harvest_start": 2,
    "harvest_full": 2, "harvest_return": 2, "harvest_unload": 2,
    "harvest_danger": 2,
}

catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
assert catalog.get("schema_version") == 1
assert set(catalog.get("factions", {})) == REQUIRED_FACTIONS
ids = set()
faction_lines = 0
for faction_id in REQUIRED_FACTIONS:
    faction = catalog["factions"][faction_id]
    lines = faction.get("lines", {})
    assert set(lines) == set(REQUIRED_EVENTS), f"{faction_id}: missing/extra line categories"
    for event_name, expected_count in REQUIRED_EVENTS.items():
        assert len(lines[event_name]) == expected_count, f"{faction_id}/{event_name}: expected {expected_count} variations"
        for line in lines[event_name]:
            line_id = line["id"]
            assert line_id not in ids, f"duplicate voice line id: {line_id}"
            ids.add(line_id)
            assert line.get("event") == event_name and line.get("text", "").strip()
            asset = line.get("asset", "")
            if asset:
                assert asset.startswith("res://assets/audio/voice/")
                path = ROOT / asset.removeprefix("res://")
                assert path.is_file(), f"missing voice file: {asset}"
                assert asset.lower().endswith(".ogg"), f"voice file must be OGG: {asset}"
            else:
                assert line.get("asset_state") == "recording_required", f"unmarked missing voice file: {line_id}"
            faction_lines += 1

system_lines = 0
for event_name, lines in catalog.get("system", {}).items():
    assert lines, f"system event without lines: {event_name}"
    for line in lines:
        assert line["id"] not in ids, f"duplicate voice line id: {line['id']}"
        ids.add(line["id"])
        assert line.get("event") == event_name and line.get("text", "").strip()
        asset = line.get("asset", "")
        if asset:
            path = ROOT / asset.removeprefix("res://")
            assert path.is_file() and asset.lower().endswith(".ogg"), f"invalid voice file: {asset}"
        else:
            assert line.get("asset_state") == "recording_required", f"unmarked missing voice file: {line['id']}"
        system_lines += 1

assert faction_lines == 96, f"unexpected faction voice line count: {faction_lines}"
assert system_lines >= 15, f"too few command/system lines: {system_lines}"
assert catalog.get("recordings_status") == "not_recorded" if not any(
    line.get("asset") for faction in catalog["factions"].values() for group in faction["lines"].values() for line in group
) else True
print(f"VOICE CATALOG: {faction_lines} faction lines, {system_lines} system lines, unique IDs and file paths valid")
