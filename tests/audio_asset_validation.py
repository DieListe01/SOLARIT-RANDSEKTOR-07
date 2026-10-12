"""Validate technical delivery properties of the authored music reference assets.

This is a format/loop-boundary check, not a replacement for listening tests.
Requires FFmpeg and FFprobe on PATH.
"""
from __future__ import annotations

import json
import math
import shutil
import struct
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "assets" / "audio" / "music_catalog.json"
WINDOW_SECONDS = 0.08
EDGE_RMS_LIMIT = 0.035
SEAM_DELTA_LIMIT = 0.06


def run(args: list[str]) -> bytes:
    result = subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return result.stdout


def samples_from(data: bytes) -> list[float]:
    usable = len(data) - (len(data) % 4)
    if usable <= 0:
        return []
    return list(struct.unpack("<" + "f" * (usable // 4), data[:usable]))


def rms(values: list[float]) -> float:
    return math.sqrt(sum(value * value for value in values) / max(1, len(values)))


def inspect_track(path: Path, expected_rate: int, expected_channels: int) -> dict:
    probe = json.loads(run([
        "ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
        "stream=sample_rate,channels,duration", "-of", "json", str(path),
    ]).decode("utf-8"))
    streams = probe.get("streams", [])
    if len(streams) != 1:
        raise AssertionError(f"{path.name}: expected one audio stream, found {len(streams)}")
    stream = streams[0]
    rate = int(stream["sample_rate"])
    channels = int(stream["channels"])
    duration = float(stream["duration"])
    if rate != expected_rate or channels != expected_channels:
        raise AssertionError(f"{path.name}: got {rate} Hz / {channels} ch, expected {expected_rate} Hz / {expected_channels} ch")

    def decode_edge(last: bool) -> list[float]:
        args = ["ffmpeg", "-v", "error"]
        if last:
            args += ["-sseof", f"-{WINDOW_SECONDS}"]
        args += ["-i", str(path)]
        if not last:
            args += ["-t", str(WINDOW_SECONDS)]
        args += ["-ac", "1", "-ar", "11025", "-f", "f32le", "pipe:1"]
        return samples_from(run(args))

    first = decode_edge(False)
    tail = decode_edge(True)
    first_rms, tail_rms = rms(first), rms(tail)
    first_sample = first[0] if first else 1.0
    last_sample = tail[-1] if tail else 1.0
    seam_delta = abs(first_sample - last_sample)
    if first_rms > EDGE_RMS_LIMIT or tail_rms > EDGE_RMS_LIMIT:
        raise AssertionError(f"{path.name}: loop edge is not faded (first RMS {first_rms:.4f}, last RMS {tail_rms:.4f})")
    if seam_delta > SEAM_DELTA_LIMIT:
        raise AssertionError(f"{path.name}: decoded loop seam delta {seam_delta:.4f} exceeds {SEAM_DELTA_LIMIT}")
    return {"file": str(path.relative_to(ROOT)), "duration_seconds": duration, "sample_rate": rate,
            "channels": channels, "first_edge_rms": first_rms, "last_edge_rms": tail_rms,
            "seam_delta": seam_delta}


def main() -> int:
    for executable in ("ffmpeg", "ffprobe"):
        if shutil.which(executable) is None:
            print(f"AUDIO ASSET VALIDATION: required executable missing: {executable}", file=sys.stderr)
            return 2
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    if "30 seconds" not in catalog.get("approval_policy", "") or "5 minutes" not in catalog.get("approval_policy", "") or "real match" not in catalog.get("approval_policy", ""):
        raise AssertionError("Music approval policy must require 30-second, 5-minute, and in-match listening")
    track_rows: list[tuple[str, dict]] = [("title", catalog["title_track"])]
    for faction, faction_data in catalog["factions"].items():
        for state, choices in faction_data["tracks"].items():
            for track in choices:
                track_rows.append((f"{faction}/{state}", track))
    results = []
    approved_count = 0
    for label, track in track_rows:
        asset_status = track.get("asset_status")
        approval = track.get("human_listening_approval")
        track_path = str(track.get("path", ""))
        if asset_status == "placeholder":
            if approval != "pending" or not track_path.endswith("_demo.ogg"):
                raise AssertionError(f"{label}: placeholder must remain pending and visibly named as a demo")
        elif asset_status == "approved":
            evidence = track.get("listening_review", {})
            required_evidence = ("reviewer", "review_date", "at_30_seconds", "at_5_minutes", "in_match")
            if approval != "approved" or any(not evidence.get(key) for key in required_evidence):
                raise AssertionError(f"{label}: approved asset is missing human listening evidence")
            if "demo" in Path(track_path).name.lower() or "placeholder" in Path(track_path).name.lower():
                raise AssertionError(f"{label}: approved asset still has a placeholder filename")
            approved_count += 1
        else:
            raise AssertionError(f"{label}: unsupported or missing asset status {asset_status!r}")
        relative = str(track["path"]).removeprefix("res://").replace("/", "/")
        path = ROOT / relative
        duration = float(track["loop_end_seconds"]) - float(track["loop_start_seconds"])
        minimum = 120.0 if label == "title" else 90.0
        if duration < minimum:
            raise AssertionError(f"{label}: catalog loop {duration:.2f}s below {minimum:.0f}s minimum")
        result = inspect_track(path, 48_000, 2)
        if abs(result["duration_seconds"] - duration) > 0.08:
            raise AssertionError(f"{label}: catalog loop {duration:.3f}s differs from file {result['duration_seconds']:.3f}s")
        results.append(result)
    expected_status = "approved" if approved_count == len(track_rows) else "placeholder_not_final"
    if catalog.get("production_status") != expected_status:
        raise AssertionError(f"Music catalog status must be {expected_status!r} for {approved_count}/{len(track_rows)} approved entries")
    out = ROOT / "test-output" / "audio_asset_validation.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(results, indent=2), encoding="utf-8")
    worst_edge = max(max(row["first_edge_rms"], row["last_edge_rms"]) for row in results)
    worst_seam = max(row["seam_delta"] for row in results)
    print(f"AUDIO ASSET VALIDATION: PASS ({len(results)} tracks; 48kHz stereo; loop metadata matches; "
          f"worst edge RMS={worst_edge:.5f}; worst seam delta={worst_seam:.5f})")
    print(f"Measurements: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
