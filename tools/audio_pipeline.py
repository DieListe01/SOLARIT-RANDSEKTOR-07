#!/usr/bin/env python3
"""Prepare, inventory, and release-gate SOLARIT audio assets.

Technical checks never grant listening approval. New masters are imported into
assets/audio/candidates as pending OGG files and must be reviewed before the
game catalogs can point at them.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
MANIFEST = AUDIO / "audio_manifest.json"
MUSIC_CATALOG = AUDIO / "music_catalog.json"
VOICE_CATALOG = AUDIO / "voice" / "voice_catalog.json"
SFX_CATALOG = AUDIO / "sfx_catalog.json"
REVIEW_CRITERIA_VERSION = "playback-review-v2-2026-10-16"
PROVISIONAL_APPROVAL_LABEL = "Vorläufige menschliche Hörabnahme für den aktuellen Entwicklungsstand – erneute Bewertung im realen Gameplay ausdrücklich vorbehalten."
PROVISIONAL_SCOPE = "development_and_gameplay_test_only"
# These cues remain runtime fallbacks outside the JSON SFX catalog. They are
# loaded and played by music_director.gd and therefore remain release-required.
RUNTIME_FALLBACK_SFX = ("build", "complete", "ready", "alarm", "error", "save", "rotate", "repair", "core_impact")
PLAYBACK_REVIEW_KEYS = (
    "gain", "volume_db", "bus", "loop", "loop_start_seconds", "loop_end_seconds",
    "ducking", "fade_in_seconds", "fade_out_seconds", "crossfade_seconds", "spatial",
    "priority", "unit_cooldown", "event_cooldown",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def command(args: list[str]) -> bytes:
    result = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        detail = result.stderr.decode("utf-8", "replace")[-4000:]
        raise RuntimeError(f"Command failed ({result.returncode}): {' '.join(args)}\n{detail}")
    return result.stdout


def probe(path: Path) -> dict[str, Any]:
    data = json.loads(command([
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration:stream=codec_name,sample_rate,channels,bits_per_sample,bits_per_raw_sample",
        "-select_streams", "a:0", "-of", "json", str(path),
    ]).decode("utf-8"))
    streams = data.get("streams", [])
    if len(streams) != 1:
        raise ValueError(f"{path}: expected exactly one audio stream, found {len(streams)}")
    stream = streams[0]
    fmt = data.get("format", {})
    return {
        "codec": str(stream.get("codec_name", "")),
        "sample_rate": int(stream.get("sample_rate", 0)),
        "channels": int(stream.get("channels", 0)),
        "bit_depth": int(stream.get("bits_per_raw_sample") or stream.get("bits_per_sample") or 0),
        "duration_seconds": round(float(fmt.get("duration", 0.0)), 4),
    }


def loudness(path: Path) -> str:
    result = subprocess.run([
        "ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-filter_complex",
        "ebur128=framelog=verbose", "-f", "null", "-",
    ], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise RuntimeError(f"ffmpeg loudness analysis failed for {path}: {result.stderr.decode('utf-8','replace')[-2000:]}")
    text = result.stderr.decode("utf-8", "replace")
    summary = text.rfind("Integrated loudness:")
    return text[summary:][-1400:] if summary >= 0 else text[-1400:]


def read_json(path: Path) -> dict[str, Any]:
    parsed = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(parsed, dict):
        raise ValueError(f"Expected a JSON object in {path}")
    return parsed


def catalog_rows() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    music = read_json(MUSIC_CATALOG)
    title = music.get("title_track", {})
    rows.append({"id": str(title.get("id", "first_signal")), "kind": "music", "faction": "global",
                 "state": "title", "catalog_path": str(title.get("path", "")),
                 "asset_status": str(title.get("asset_status", "missing")),
                 "approval": str(title.get("human_listening_approval", "pending")),
                 "playback": {key: title[key] for key in PLAYBACK_REVIEW_KEYS if key in title},
                 "source": title.get("source", {}), "license": title.get("license", {"status": "unknown"})})
    for faction, faction_data in music.get("factions", {}).items():
        for state, choices in faction_data.get("tracks", {}).items():
            for track in choices:
                rows.append({"id": str(track.get("id", "")), "kind": "music", "faction": faction,
                             "state": state, "catalog_path": str(track.get("path", "")),
                             "asset_status": str(track.get("asset_status", "missing")),
                             "approval": str(track.get("human_listening_approval", "pending")),
                             "playback": {key: track[key] for key in PLAYBACK_REVIEW_KEYS if key in track},
                             "source": track.get("source", {}), "license": track.get("license", {"status": "unknown"})})
    for stinger, track in music.get("global_stingers", {}).items():
        rows.append({"id": str(track.get("id", f"stinger_{stinger}")), "kind": "music", "faction": "global",
                     "state": f"stinger_{stinger}", "catalog_path": str(track.get("path", "")),
                     "asset_status": str(track.get("asset_status", "missing")),
                     "approval": str(track.get("human_listening_approval", "pending")),
                     "playback": {key: track[key] for key in PLAYBACK_REVIEW_KEYS if key in track},
                     "source": track.get("source", {}), "license": track.get("license", {"status": "unknown"})})
    if SFX_CATALOG.exists():
        sfx_catalog = read_json(SFX_CATALOG)
        for cue, clips in sfx_catalog.get("cues", {}).items():
            for clip in clips:
                rowsource = {"name": clip.get("source", ""), "url": clip.get("source_url", "")}
                rowsource.update({key: value for key, value in clip.items() if key in ("author", "notes")})
                rows.append({"id": str(clip.get("id", cue)), "kind": "sfx", "faction": "global",
                             "state": cue, "catalog_path": str(clip.get("path", "")),
                             "asset_status": str(clip.get("asset_status", "missing")),
                             "approval": str(clip.get("human_listening_approval", "pending")),
                             "playback": {key: clip[key] for key in PLAYBACK_REVIEW_KEYS if key in clip},
                             "source": rowsource,
                             "license": clip.get("license", {"status": "unknown"})})
    voice = read_json(VOICE_CATALOG)
    for faction, faction_data in voice.get("factions", {}).items():
        for event, lines in faction_data.get("lines", {}).items():
            for line in lines:
                rows.append({"id": str(line.get("id", "")), "kind": "voice", "faction": faction,
                             "state": event, "catalog_path": str(line.get("asset", "")),
                             "asset_status": str(line.get("asset_status", "recorded" if line.get("asset") else "missing")),
                             "approval": str(line.get("human_listening_approval", line.get("approval", "pending"))),
                             "playback": {key: line[key] for key in PLAYBACK_REVIEW_KEYS if key in line},
                             "source": line.get("source", {}), "license": line.get("license", {"status": "unknown"})})
    for event, lines in voice.get("system", {}).items():
        for line in lines:
            rows.append({"id": str(line.get("id", "")), "kind": "voice", "faction": "neutral",
                         "state": event, "catalog_path": str(line.get("asset", "")),
                         "asset_status": str(line.get("asset_status", "recorded" if line.get("asset") else "missing")),
                         "approval": str(line.get("human_listening_approval", line.get("approval", "pending"))),
                         "playback": {key: line[key] for key in PLAYBACK_REVIEW_KEYS if key in line},
                         "source": line.get("source", {}), "license": line.get("license", {"status": "unknown"})})
    # These hard-coded fallback cues are called by the live event/UI code and
    # are not represented in sfx_catalog.json. Their old inventory IDs are
    # retained so byte-bound review evidence and provenance map by path.
    for cue in RUNTIME_FALLBACK_SFX:
        rows.append({"id": "file_" + cue, "kind": "sfx", "faction": "global", "state": cue,
                     "catalog_path": f"res://assets/audio/{cue}.wav", "asset_status": "placeholder",
                     "approval": "pending", "release_required": True,
                     "playback": {}, "source": {}, "license": {"status": "unknown"}})
    for row in rows:
        row["release_required"] = True
    return rows


def playback_signature(row: dict[str, Any]) -> str:
    """Bind listening evidence to asset bytes and the effective playback context."""
    kind = str(row.get("kind", "unknown"))
    state = str(row.get("state", ""))
    configured = row.get("playback", {})
    if not isinstance(configured, dict):
        configured = {}
    if kind == "music":
        runtime = {
            "bus": "Music", "gain_source": "user_music_volume_and_state_gain",
            "loop_default": not state.startswith("stinger_"),
            "crossfade_seconds": 4.0,
            "state_transition": {
                "minimum_dwell_seconds": 20.0,
                "minimum_pending_stability_seconds": 6.0,
                "urgent_states": ["BASE_UNDER_ATTACK", "VICTORY", "DEFEAT"],
                "bar_aligned": True,
            },
            "voice_duck": {"gain": 0.5011872, "attack_rate": 9.0, "release_rate": 1.5},
        }
    elif kind == "voice":
        runtime = {"bus": "Voice", "gain_source": "user_voice_volume_and_event_gain", "loop_default": False,
                   "spatial_default": False, "music_duck": {"gain": 0.5011872, "attack_rate": 9.0, "release_rate": 1.5}}
    elif kind == "sfx":
        runtime = {"bus": "cue-dependent: UI/Combat/SFX", "gain_source": "user_sfx_volume_and_event_gain",
                   "loop_default": False, "spatial_default": "2D event attenuation when world-positioned"}
    else:
        runtime = {"bus": "project-configured", "gain_source": "project-configured", "loop_default": False}
    context = {"criteria_version": REVIEW_CRITERIA_VERSION, "kind": kind, "faction": str(row.get("faction", "")),
               "state": state, "configured_playback": configured, "runtime_profile": runtime}
    canonical = json.dumps(context, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def preserve_manifest_review_data(
    row: dict[str, Any], old: dict[str, Any], *, current_sha256: str | None = None,
    current_playback_signature: str | None = None,
) -> dict[str, Any]:
    """Carry review forward only when audio bytes and playback context match."""
    for key in ("source", "license", "listening_review", "approval", "development_listening_review"):
        if key in ("listening_review", "development_listening_review"):
            reviewed_hash = str(old.get("sha256", ""))
            reviewed_playback = str(old.get("playback_signature", ""))
            if (not current_sha256 or reviewed_hash != current_sha256
                    or not current_playback_signature or reviewed_playback != current_playback_signature):
                continue
        if key in old and key not in row:
            row[key] = old[key]
        elif key == "license" and row.get(key, {}).get("status") not in ("cleared", "pending", "rejected"):
            if old.get(key, {}).get("status") not in (None, "unknown"):
                row[key] = old[key]
    return row


def inventory() -> dict[str, Any]:
    rows = catalog_rows()
    referenced = {str(row.get("catalog_path", "")) for row in rows if row.get("catalog_path")}
    existing = read_json(MANIFEST) if MANIFEST.exists() else {}
    old_by_id = {str(row.get("id")): row for row in existing.get("assets", [])}
    old_by_path = {str(row.get("catalog_path")): row for row in existing.get("assets", []) if row.get("catalog_path")}
    used_ids = {str(row.get("id", "")) for row in rows}
    for path in sorted(AUDIO.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in {".wav", ".ogg", ".mp3", ".flac"}:
            continue
        resource = "res://" + path.relative_to(ROOT).as_posix()
        if resource in referenced:
            continue
        if resource in old_by_path and str(old_by_path[resource].get("id", "")) not in used_ids:
            # Keep candidate IDs, provenance and pending/approved state across refreshes.
            rows.append(dict(old_by_path[resource]))
            used_ids.add(str(old_by_path[resource].get("id", "")))
            referenced.add(resource)
            continue
        try:
            technical = probe(path)
        except Exception as error:  # Inventory preserves broken files for the gate to report.
            technical = {"probe_error": str(error)}
        rows.append({"id": "file_" + re.sub(r"[^a-z0-9]+", "_", path.stem.lower()).strip("_"),
                     "kind": "sfx" if "/sfx/" in resource else "legacy_audio",
                     "faction": "global", "state": path.stem, "catalog_path": resource,
                     "asset_status": "placeholder", "approval": "pending", "release_required": False,
                     "license": {"status": "unknown"}, "technical": technical})
    for row in rows:
        old = old_by_id.get(str(row["id"]), {})
        path_value = str(row.get("catalog_path", ""))
        current_hash: str | None = None
        if path_value.startswith("res://"):
            disk_path = ROOT / path_value.removeprefix("res://")
            if disk_path.is_file():
                try:
                    row["technical"] = probe(disk_path)
                    current_hash = sha256(disk_path)
                    row["sha256"] = current_hash
                except Exception as error:
                    row["technical"] = {"probe_error": str(error)}
            else:
                row["technical"] = {"missing": True}
        else:
            row["technical"] = {"missing": True}
        # Keep authored provenance and approval only for the exact reviewed bytes.
        current_playback_signature = playback_signature(row)
        row["playback_signature"] = current_playback_signature
        preserve_manifest_review_data(row, old, current_sha256=current_hash,
                                      current_playback_signature=current_playback_signature)
        if "release_required" not in row:
            row["release_required"] = False
    return {
        "schema_version": 1,
        "generated_date": date.today().isoformat(),
        "policy": "Technical checks never grant human listening approval. Only active release-required assets participate in the public release gate; inactive candidate/archive entries remain inventoried without blocking.",
        "assets": rows,
    }


def save_manifest(manifest: dict[str, Any]) -> None:
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def release_blockers(row: dict[str, Any], measured: dict[str, Any]) -> list[str]:
    """Return release blockers for one asset, without mutating its approval state."""
    asset_id = str(row.get("id", "<no-id>"))
    blockers: list[str] = []
    if row.get("asset_status") != "approved":
        blockers.append(f"{asset_id}: asset_status={row.get('asset_status', 'missing')}")
    if row.get("approval") != "approved":
        blockers.append(f"{asset_id}: approval={row.get('approval', 'pending')}")
    license_data = row.get("license", {})
    if not license_data.get("name") or license_data.get("status") != "cleared" or license_data.get("commercial_use") is not True:
        blockers.append(f"{asset_id}: commercial license is not explicitly cleared")
    review = row.get("listening_review", {})
    # Ask for evidence that fits the asset. Duration-based checks are useful for
    # music loops, but make no sense for a 1-second confirmation SFX or a short
    # unit bark. Every type still requires a named human reviewer, date, and an
    # in-match mix check before it can be released.
    review_fields = {
        "music": ("at_30_seconds", "at_5_minutes", "in_match"),
        "voice": ("clarity", "pronunciation", "faction_identity", "repeat_test", "in_match"),
        "sfx": ("function_fit", "mix_level", "in_match"),
    }
    needed = ("reviewer", "review_date", *review_fields.get(str(row.get("kind", "")), ("in_match",)))
    if any(not review.get(field) for field in needed):
        blockers.append(f"{asset_id}: required human listening review is incomplete")
    if measured.get("sample_rate") != 48_000:
        blockers.append(f"{asset_id}: runtime sample rate is {measured.get('sample_rate', 'unknown')}, expected 48000 Hz")
    if row.get("kind") == "music" and measured.get("channels") != 2:
        blockers.append(f"{asset_id}: music must be stereo")
    if row.get("kind") == "voice" and measured.get("channels") not in (1, 2):
        blockers.append(f"{asset_id}: invalid voice channel count")
    return blockers


def catalog_coverage_blockers() -> list[str]:
    return music_coverage_blockers(read_json(MUSIC_CATALOG))


def music_coverage_blockers(music: dict[str, Any]) -> list[str]:
    blockers: list[str] = []
    required_states = {"calm_a", "calm_b", "contact", "battle_low", "battle_high", "critical"}
    for faction in ("forge", "drift", "lumen"):
        available = set(music.get("factions", {}).get(faction, {}).get("tracks", {}))
        for missing in sorted(required_states - available):
            blockers.append(f"music catalog missing required state {faction}/{missing}")
    required_stingers = {"mission_start", "objective_complete", "major_alert", "victory", "defeat"}
    available_stingers = set(music.get("global_stingers", {}))
    for missing in sorted(required_stingers - available_stingers):
        blockers.append(f"music catalog missing required global stinger {missing}")
    return blockers


def check_manifest(strict: bool) -> list[str]:
    if not MANIFEST.is_file():
        return [f"audio manifest missing: {MANIFEST.relative_to(ROOT)}"]
    manifest = read_json(MANIFEST)
    errors: list[str] = []
    seen: set[str] = set()
    catalog_by_id = {str(row.get("id", "")): row for row in catalog_rows()}
    for row in manifest.get("assets", []):
        asset_id = str(row.get("id", "<no-id>"))
        if asset_id in seen:
            errors.append(f"duplicate asset id: {asset_id}")
        seen.add(asset_id)
        path_value = str(row.get("catalog_path", ""))
        is_release_required = bool(row.get("release_required", False))
        if strict and not is_release_required:
            # Unreferenced archive/candidate files remain inventoried but do
            # not participate in the public release decision.
            continue
        if not path_value.startswith("res://"):
            if not strict and row.get("asset_status") == "missing" and not path_value:
                continue
            errors.append(f"{asset_id}: invalid or missing res:// path")
            continue
        path = ROOT / path_value.removeprefix("res://")
        if not path.is_file():
            errors.append(f"{asset_id}: missing file {path_value}")
            continue
        try:
            measured = probe(path)
        except Exception as error:
            errors.append(f"{asset_id}: corrupt/unreadable file: {error}")
            continue
        if row.get("sha256") and row["sha256"] != sha256(path):
            errors.append(f"{asset_id}: SHA-256 mismatch; refresh inventory after a reviewed asset change")
        current = catalog_by_id.get(asset_id)
        if current is not None and row.get("playback_signature") != playback_signature(current):
            if not strict or is_release_required:
                errors.append(f"{asset_id}: playback signature changed; refresh inventory and re-review before release")
        if strict:
            errors.extend(release_blockers(row, measured))
    if strict:
        # Ensure the manifest still covers every catalog row; newly added cues cannot bypass the gate.
        manifest_rows = {str(row.get("id", "")): row for row in manifest.get("assets", [])}
        for row in catalog_rows():
            manifest_row = manifest_rows.get(str(row["id"]))
            if manifest_row is None:
                errors.append(f"catalog asset absent from manifest: {row['id']}")
            elif row.get("release_required", False) and not manifest_row.get("release_required", False):
                errors.append(f"catalog asset {row['id']}: release-required flag is missing from manifest")
        errors.extend(catalog_coverage_blockers())
    return errors


def write_gate_report(errors: list[str], strict: bool) -> Path:
    report_dir = ROOT / "test-output"
    report_dir.mkdir(parents=True, exist_ok=True)
    report_path = report_dir / "audio_release_gate.json"
    report = {
        "gate": "release" if strict else "manifest",
        "status": "blocked" if errors else "pass",
        "issue_count": len(errors),
        "issues": errors,
        "approval_policy": "Final public release requires final per-asset approval and listening criteria; provisional development approval does not satisfy this gate.",
        "provisional_approval_label": PROVISIONAL_APPROVAL_LABEL,
    }
    if MANIFEST.is_file():
        assets = read_json(MANIFEST).get("assets", [])
        required = [row for row in assets if row.get("release_required", False)]
        inactive = [row for row in assets if not row.get("release_required", False)]
        active_catalog = {str(row.get("id", "")): row for row in catalog_rows()}
        def has_current_provisional_review(row: dict[str, Any]) -> bool:
            review = row.get("development_listening_review", {})
            if not (review.get("status") == "provisional"
                    and review.get("scope") == PROVISIONAL_SCOPE
                    and review.get("sha256") == row.get("sha256")
                    and review.get("playback_signature") == row.get("playback_signature")):
                return False
            current_path = str(row.get("catalog_path", ""))
            file_path = ROOT / current_path.removeprefix("res://")
            if not file_path.is_file() or sha256(file_path) != review.get("sha256"):
                return False
            current_row = active_catalog.get(str(row.get("id", "")))
            return current_row is None or playback_signature(current_row) == review.get("playback_signature")
        report["asset_counts"] = {
            "manifest_total": len(assets),
            "active_release_required": len(required),
            "active_provisional_human_approval_current": sum(has_current_provisional_review(row) for row in required),
            "active_final_approval_pending": sum(row.get("approval") != "approved" for row in required),
            "inactive_pending_not_release_blocking": sum(row.get("approval") != "approved" or row.get("asset_status") in {"candidate", "placeholder", "missing"} for row in inactive),
            "active_pending_release_status": sum(row.get("approval") != "approved" or row.get("asset_status") in {"candidate", "placeholder", "missing"} for row in required),
        }
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report_path


def record_provisional_approval(reviewer: str) -> tuple[int, int]:
    """Record provisional development listening approval, never final release approval."""
    manifest = inventory()
    recorded = 0
    for row in manifest.get("assets", []):
        if not row.get("release_required", False):
            continue
        if row.get("technical", {}).get("missing") or row.get("technical", {}).get("probe_error"):
            continue
        row["development_listening_review"] = {
            "status": "provisional",
            "scope": PROVISIONAL_SCOPE,
            "label": PROVISIONAL_APPROVAL_LABEL,
            "reviewer": reviewer,
            "review_date": date.today().isoformat(),
            "statement": "Aktive Audioassets sind für Entwicklung und Gameplay-Test vorläufig angehört/freigegeben; finale qualitative Hörabnahme bleibt ausdrücklich offen.",
            "sha256": row.get("sha256", ""),
            "playback_signature": row.get("playback_signature", ""),
        }
        recorded += 1
    save_manifest(manifest)
    inactive_pending = sum(1 for row in manifest.get("assets", [])
                           if not row.get("release_required", False)
                           and (row.get("approval") != "approved" or row.get("asset_status") in {"candidate", "placeholder", "missing"}))
    return recorded, inactive_pending


def prepare_wav(args: argparse.Namespace) -> int:
    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
        print("ERROR: ffmpeg and ffprobe are required", file=sys.stderr)
        return 2
    source = Path(args.prepare_wav).resolve()
    if not source.is_file():
        print(f"ERROR: source WAV missing: {source}", file=sys.stderr)
        return 2
    if not args.license_name or not args.source_name or not args.source_url:
        print("ERROR: provenance and license name, source name, source URL are mandatory", file=sys.stderr)
        return 2
    try:
        info = probe(source)
    except Exception as error:
        print(f"ERROR: cannot inspect source: {error}", file=sys.stderr)
        return 2
    if info["codec"] != "pcm_s24le" or info["sample_rate"] != 48_000:
        print("ERROR: master must be PCM 24-bit 48 kHz WAV; no silent resampling/bit-depth change is allowed", file=sys.stderr)
        return 2
    if args.kind == "music" and info["channels"] != 2:
        print("ERROR: music master must be stereo", file=sys.stderr)
        return 2
    if args.kind == "voice" and info["channels"] != 1:
        print("ERROR: voice master must be mono", file=sys.stderr)
        return 2
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{1,80}", args.id):
        print("ERROR: id must use lowercase letters, numbers, _ or -", file=sys.stderr)
        return 2
    out_dir = AUDIO / "candidates" / args.kind
    out_dir.mkdir(parents=True, exist_ok=True)
    output = out_dir / f"{args.id}.ogg"
    if output.exists():
        print(f"ERROR: refusing to overwrite candidate: {output}", file=sys.stderr)
        return 2
    try:
        command(["ffmpeg", "-y", "-i", str(source), "-c:a", "libvorbis", "-q:a", "6", str(output)])
        runtime = probe(output)
        loudness_report = loudness(source)
    except Exception as error:
        output.unlink(missing_ok=True)
        print(f"ERROR: candidate preparation failed: {error}", file=sys.stderr)
        return 2
    manifest = read_json(MANIFEST) if MANIFEST.exists() else inventory()
    if any(str(row.get("id")) == args.id for row in manifest.get("assets", [])):
        output.unlink(missing_ok=True)
        print(f"ERROR: duplicate id in manifest: {args.id}", file=sys.stderr)
        return 2
    row = {
        "id": args.id, "kind": args.kind, "faction": args.faction, "state": args.state,
        "catalog_path": "res://" + output.relative_to(ROOT).as_posix(), "asset_status": "candidate",
        "approval": "pending", "source": {"name": args.source_name, "url": args.source_url,
                    "master_path": str(source), "master_sha256": sha256(source)},
        "license": {"name": args.license_name, "status": "pending_verification",
                    "commercial_use": None, "attribution": args.attribution or "not yet verified"},
        "technical": runtime, "sha256": sha256(output),
        "loudness_report": loudness_report, "prepared_date": date.today().isoformat(),
    }
    manifest.setdefault("assets", []).append(row)
    save_manifest(manifest)
    print(f"CANDIDATE PENDING: {row['catalog_path']} ({runtime['sample_rate']} Hz, {runtime['channels']} ch, {runtime['duration_seconds']:.2f}s)")
    print("No runtime catalog was changed; license and human listening approval remain pending.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--refresh-manifest", action="store_true", help="inventory catalogs/files; never grants approval")
    modes.add_argument("--check", action="store_true", help="check manifest consistency and file readability")
    modes.add_argument("--release-gate", action="store_true", help="fail if any active release-required audio asset is missing, unapproved, or uncleared")
    modes.add_argument("--record-provisional-approval", action="store_true", help="record user's provisional development listening approval for active release-required assets only")
    modes.add_argument("--prepare-wav", metavar="PATH", help="convert a verified 48kHz/24-bit WAV master into a pending candidate OGG")
    parser.add_argument("--id", help="unique asset id for --prepare-wav")
    parser.add_argument("--kind", choices=("music", "voice", "sfx"), help="candidate type")
    parser.add_argument("--faction", default="global")
    parser.add_argument("--state", default="candidate")
    parser.add_argument("--source-name")
    parser.add_argument("--source-url")
    parser.add_argument("--license-name")
    parser.add_argument("--attribution")
    args = parser.parse_args()
    for executable in ("ffmpeg", "ffprobe"):
        if shutil.which(executable) is None:
            print(f"ERROR: required executable missing: {executable}", file=sys.stderr)
            return 2
    if args.refresh_manifest:
        manifest = inventory()
        save_manifest(manifest)
        print(f"Audio inventory refreshed: {len(manifest['assets'])} catalog/file entries; all unapproved entries remain pending.")
        return 0
    if args.record_provisional_approval:
        recorded, inactive_pending = record_provisional_approval("project owner (explicit user confirmation)")
        print(f"PROVISIONAL DEVELOPMENT LISTENING APPROVAL: {recorded} active release-required assets; {inactive_pending} inactive assets remain pending.")
        print(PROVISIONAL_APPROVAL_LABEL)
        return 0
    if args.prepare_wav:
        if not all((args.id, args.kind, args.source_name, args.source_url, args.license_name)):
            parser.error("--prepare-wav requires --id, --kind, --source-name, --source-url, and --license-name")
        return prepare_wav(args)
    errors = check_manifest(strict=args.release_gate)
    report_path = write_gate_report(errors, args.release_gate)
    if errors:
        label = "RELEASE GATE BLOCKED" if args.release_gate else "AUDIO MANIFEST CHECK FAILED"
        print(f"{label}: {len(errors)} issue(s); full report: {report_path.relative_to(ROOT)}")
        for error in errors[:50]:
            print(f" - {error}")
        if len(errors) > 50:
            print(f" - ... {len(errors) - 50} additional issue(s) are in the JSON report")
        return 1
    print(f"{'AUDIO MANIFEST CHECK' if args.check else 'AUDIO RELEASE GATE'}: PASS; report: {report_path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
