#!/usr/bin/env python3
"""Master the reviewed, freely licensed audio sources into SOLARIT runtime OGGs.

Source files are kept in an ignored staging directory. This emits 48 kHz / 24-bit
intermediate WAV masters there, then Vorbis runtime files under assets/audio.
Every imported asset remains a candidate until a human listening review.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
SOURCE_ROOT = ROOT / "test-output" / "audio-tools" / "sources"
PROJECT_SOURCES = ROOT / "tools" / "audio_sources"
CYBER = SOURCE_ROOT / "cyberpunk"
DARK = SOURCE_ROOT / "dark_pack" / "ogg"
CATALOG = AUDIO / "music_catalog.json"

SOURCES: dict[str, dict[str, str]] = {
    "factory": {"file": "Factory.ogg", "root": "source", "author": "yd", "url": "https://opengameart.org/content/factory-ambiance", "license": "CC0 1.0"},
    "inevitable": {"file": "inevitable.wav", "root": "source", "author": "vitalezzz", "url": "https://opengameart.org/content/inevitable", "license": "CC0 1.0"},
    "determined": {"file": "determined_pursuit_loop.wav", "root": "source", "author": "Emma_MA", "url": "https://opengameart.org/content/determined-pursuit-epic-orchestra-loop", "license": "CC0 / Public Domain"},
    "prepare": {"file": "prepare_to_fight.mp3", "root": "source", "author": "Basil", "url": "https://opengameart.org/content/prepare-to-fight", "license": "CC0 1.0"},
    "sector": {"file": "sector.ogg", "root": "dark", "author": "SRG774", "url": "https://opengameart.org/content/dark-sci-fi-audio-pack", "license": "CC0 1.0"},
    "airy": {"file": "airy.ogg", "root": "dark", "author": "SRG774", "url": "https://opengameart.org/content/dark-sci-fi-audio-pack", "license": "CC0 1.0"},
    "urgent": {"file": "urgent.ogg", "root": "dark", "author": "SRG774", "url": "https://opengameart.org/content/dark-sci-fi-audio-pack", "license": "CC0 1.0"},
    "transmission": {"file": "transmission.ogg", "root": "dark", "author": "SRG774", "url": "https://opengameart.org/content/dark-sci-fi-audio-pack", "license": "CC0 1.0"},
    "victory": {"file": "victory.ogg", "root": "dark", "author": "SRG774", "url": "https://opengameart.org/content/dark-sci-fi-audio-pack", "license": "CC0 1.0"},
    "welcome": {"file": "welcome_mix_110bpm.ogg", "root": "cyber", "author": "Alexander Ehlers / tricksntraps", "url": "https://opengameart.org/content/t-t-free-cyberpunk-pack-2", "license": "CC0 1.0"},
    "ai_fight": {"file": "ai_fight_120bpm.ogg", "root": "cyber", "author": "Alexander Ehlers / tricksntraps", "url": "https://opengameart.org/content/t-t-free-cyberpunk-pack-2", "license": "CC0 1.0"},
    "electric": {"file": "electric_stream_180bpm.ogg", "root": "cyber", "author": "Alexander Ehlers / tricksntraps", "url": "https://opengameart.org/content/t-t-free-cyberpunk-pack-2", "license": "CC0 1.0"},
    "cyborg": {"file": "jumping_cyborg_110bpm.ogg", "root": "cyber", "author": "Alexander Ehlers / tricksntraps", "url": "https://opengameart.org/content/t-t-free-cyberpunk-pack-2", "license": "CC0 1.0"},
    "new_factory": {"file": "new_factory_129bpm.ogg", "root": "cyber", "author": "Alexander Ehlers / tricksntraps", "url": "https://opengameart.org/content/t-t-free-cyberpunk-pack-2", "license": "CC0 1.0"},
    "strange": {"file": "strange_experiments_80bpm.ogg", "root": "cyber", "author": "Alexander Ehlers / tricksntraps", "url": "https://opengameart.org/content/t-t-free-cyberpunk-pack-2", "license": "CC0 1.0"},
    "overload": {"file": "system_overload_154bpm.ogg", "root": "cyber", "author": "Alexander Ehlers / tricksntraps", "url": "https://opengameart.org/content/t-t-free-cyberpunk-pack-2", "license": "CC0 1.0"},
    "sewers": {"file": "through_the_sewers_1766bpm.ogg", "root": "cyber", "author": "Alexander Ehlers / tricksntraps", "url": "https://opengameart.org/content/t-t-free-cyberpunk-pack-2", "license": "CC0 1.0"},
    "expanse": {"file": "our_expanse_loop.mp3", "root": "project", "author": "Bobjt", "url": "https://opengameart.org/content/our-expanse", "license": "CC0 1.0"},
    "final_battle": {"file": "the_final_battle.ogg", "root": "project", "author": "skrjablin", "url": "https://opengameart.org/content/the-final-battle", "license": "CC0 1.0"},
    "graveyard": {"file": "space_graveyard.mp3", "root": "candidate", "author": "TinyWorlds", "title": "Space Graveyard - Ambient Track", "url": "https://opengameart.org/content/space-graveyard-ambient-track", "license": "CC0 1.0"},
    "epic_fight": {"file": "bombastic/epic_fight_theme.mp3", "root": "candidate", "author": "Tarush Singhal", "title": "Epic Fight Theme / Boss Battle", "url": "https://opengameart.org/content/epic-fight-themeboss-battle", "license": "CC0 1.0"},
    "battle_theme_a": {"file": "bombastic/battle_theme_a.mp3", "root": "candidate", "author": "cynicmusic / pixelsphere", "title": "Battle Theme A", "url": "https://opengameart.org/content/battle-theme-a", "license": "CC0 1.0"},
    "noisy_battle": {"file": "noisy_battle.ogg", "root": "candidate", "author": "Some Weirdo", "title": "Noisy Battle", "url": "https://opengameart.org/content/noisy-battle", "license": "CC0 1.0"},
    "space_battle": {"file": "bombastic/space_battle_bpm130.ogg", "root": "candidate", "author": "MintoDog", "title": "Space Battle", "url": "https://opengameart.org/content/space-battle", "license": "CC0 1.0"},
}


def source_path(name: str) -> Path:
    spec = SOURCES[name]
    base = {"source": SOURCE_ROOT, "project": PROJECT_SOURCES, "candidate": PROJECT_SOURCES / "candidates",
            "dark": DARK, "cyber": CYBER}[spec["root"]]
    return base / spec["file"]


def ffmpeg(args: list[str]) -> None:
    result = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args], cwd=ROOT,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise RuntimeError(result.stderr.decode("utf-8", "replace")[-3000:])


def audio_duration(source: Path) -> float:
    result = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                             "-of", "default=noprint_wrappers=1:nokey=1", str(source)], cwd=ROOT,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
    return float(result.stdout.strip())


def master_ogg(source: Path, output: Path, masters: Path, start: float = 0.0, duration: float | None = None,
               target_duration: float | None = None, overwrite: bool = False, fade_edges: bool = True) -> None:
    if output.is_file() and not overwrite:
        return
    if not source.is_file() or source.stat().st_size == 0:
        raise FileNotFoundError(f"Missing source audio: {source}")
    output.parent.mkdir(parents=True, exist_ok=True)
    master = masters / (output.stem + ".wav")
    trim = []
    if start > 0.0:
        trim += ["-ss", str(start)]
    if duration is not None:
        trim += ["-t", str(duration)]
    elif target_duration is not None:
        trim += ["-t", str(target_duration)]
    length = duration if duration is not None else target_duration
    fade = 0.35
    fade_filter = ""
    if fade_edges and length is not None and length > fade * 2:
        fade_filter = f",afade=t=in:st=0:d={fade},afade=t=out:st={length-fade}:d={fade}"
    af = f"loudnorm=I=-18:TP=-1.5:LRA=11{fade_filter},aresample=48000"
    repeat = ["-stream_loop", "-1"] if target_duration is not None else []
    ffmpeg([*repeat, "-i", str(source), *trim, "-af", af, "-ar", "48000", "-ac", "2", "-c:a", "pcm_s24le", str(master)])
    ffmpeg(["-i", str(master), "-c:a", "libvorbis", "-q:a", "6", str(output)])


def entry(asset_id: str, path: str, source_id: str, bpm: int, intensity: str, *, loop: bool = True) -> dict[str, Any]:
    provenance = SOURCES[source_id]
    resource_path = path.replace(chr(92), "/")
    return {
        "id": asset_id, "path": f"res://assets/audio/{resource_path}", "bpm": bpm,
        "beats_per_bar": 4, "beat_unit": 4, "loop_start_seconds": 0.0,
        "loop_end_seconds": 180.0 if loop else 0.0, "weight": 1.0,
        "intensity": intensity, "transition_points_bars": [0, 8, 16, 24, 32],
        "asset_status": "candidate", "human_listening_approval": "pending",
        "source": {"author": provenance["author"], "url": provenance["url"], **({"title": provenance["title"]} if provenance.get("title") else {})},
        "license": {"name": provenance["license"], "status": "cleared", "commercial_use": True,
                    "attribution": provenance["author"]},
    }


def build(overwrite: bool = False) -> None:
    with tempfile.TemporaryDirectory(prefix="solarit_audio_masters_", dir=ROOT / "test-output") as temp:
        masters = Path(temp)
        output: dict[str, Path] = {}
        mappings = {
            "factory": ("factory", "music/global/factory_ambience.ogg"),
            "kobalt_calm_b": ("new_factory", "music/kobalt/calm_b.ogg"),
            "kobalt_contact": ("welcome", "music/kobalt/contact.ogg"),
            "kobalt_battle_low": ("ai_fight", "music/kobalt/battle_low.ogg"),
            "kobalt_battle_high": ("determined", "music/kobalt/battle_high.ogg"),
            "kobalt_battle_high_theme_a": ("battle_theme_a", "music/kobalt/battle_high_theme_a.ogg"),
            "kobalt_critical": ("overload", "music/kobalt/critical.ogg"),
            "wanderpakt_calm": ("sewers", "music/wanderpakt/calm_a.ogg"),
            "wanderpakt_calm_b": ("graveyard", "music/wanderpakt/calm_b.ogg"),
            "wanderpakt_contact": ("electric", "music/wanderpakt/contact.ogg"),
            "wanderpakt_battle_low": ("cyborg", "music/wanderpakt/battle_low.ogg"),
            "wanderpakt_battle_high": ("final_battle", "music/wanderpakt/battle_high.ogg"),
            "wanderpakt_battle_high_epic": ("epic_fight", "music/wanderpakt/battle_high_epic.ogg"),
            "wanderpakt_critical": ("prepare", "music/wanderpakt/critical.ogg"),
            "prisma_calm_a": ("sector", "music/prisma/calm_a.ogg"),
            "prisma_calm_b": ("airy", "music/prisma/calm_b.ogg"),
            "prisma_contact": ("strange", "music/prisma/contact.ogg"),
            "prisma_battle_low": ("inevitable", "music/prisma/battle_low.ogg"),
            "prisma_battle_high": ("urgent", "music/prisma/battle_high.ogg"),
            "prisma_critical": ("transmission", "music/prisma/critical.ogg"),
        }
        # One deterministic OGG per distinct source; paths can be shared by states/factions.
        source_targets: dict[str, Path] = {}
        master_ogg(source_path("expanse"), AUDIO / "music/global/first_signal.ogg", masters,
                   target_duration=148.4, overwrite=overwrite)
        # A source may feed several faction/state files. Bake every distinct
        # runtime path once; sharing one source file path across states is
        # handled explicitly in the catalog below.
        for source_id, relpath in mappings.values():
            target = AUDIO / relpath
            source_targets[relpath] = target
            if overwrite or not target.exists():
                if source_id == "graveyard":
                    # Preserve the full ambient loop and apply the same short
                    # anti-click edge fades as other runtime loop masters.
                    source = source_path(source_id)
                    master_ogg(source, target, masters, target_duration=audio_duration(source), overwrite=overwrite)
                else:
                    master_ogg(source_path(source_id), target, masters, target_duration=180.0, overwrite=overwrite)
        for source_id, relpath in (("epic_fight", "music/wanderpakt/battle_high_epic.ogg"),
                                   ("battle_theme_a", "music/kobalt/battle_high_theme_a.ogg"),
                                   ("noisy_battle", "music/prisma/battle_high_noisy.ogg"),
                                   ("space_battle", "music/prisma/space_battle.ogg")):
            source = source_path(source_id)
            if source_id == "space_battle":
                master_ogg(source, AUDIO / relpath, masters, target_duration=audio_duration(source) * 2.0,
                           overwrite=overwrite, fade_edges=True)
            else:
                master_ogg(source, AUDIO / relpath, masters, target_duration=180.0, overwrite=overwrite)
        for key, (_, relpath) in mappings.items():
            output[key] = Path(relpath)
        output["first_signal"] = Path("music/global/first_signal.ogg")

        # Four short authored stingers are cut from CC0 full mixes, with graceful tails.
        stinger_specs = {
            "mission_start": ("inevitable", 0.0, 10.0),
            "objective_complete": ("victory", 0.0, 5.5),
            "major_alert": ("urgent", 0.0, 7.5),
            "victory": ("determined", 94.0, 10.0),
            "defeat": ("transmission", 18.0, 8.0),
        }
        stingers: dict[str, dict[str, Any]] = {}
        for name, (source_id, start, duration) in stinger_specs.items():
            relpath = f"music/global/stingers/{name}.ogg"
            master_ogg(source_path(source_id), AUDIO / relpath, masters, start, duration, overwrite=overwrite)
            track = entry(f"stinger_{name}", relpath, source_id, 120, "stinger", loop=False)
            track["loop_end_seconds"] = 0.0
            stingers[name] = track

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    catalog["schema_version"] = 3
    catalog["title_track"] = entry("first_signal", str(output["first_signal"]), "expanse", 96, "title")
    catalog["title_track"].update({"loop_end_seconds": 148.4, "transition_points_bars": [0, 8, 16, 24, 32, 40, 48, 56]})
    specs = {
        "forge": {"display_name": "Kobalt-Konsortium", "motif": [0, 7, 3, 10], "identity": "schwer, industriell, diszipliniert",
            "calm_a": ("kobalt_calm_b", 129, "low"), "calm_b": ("factory", 108, "low"),
                  "contact": ("kobalt_contact", 110, "low"), "battle_low": ("kobalt_battle_low", 120, "medium"),
                  "battle_high": ("kobalt_battle_high", 116, "high"), "critical": ("kobalt_critical", 154, "high")},
        "drift": {"display_name": "Wanderpakt", "motif": [0, 2, 7, 5], "identity": "rau, mobil, gebrochen",
                  "calm_a": ("wanderpakt_calm", 108, "low"), "calm_b": ("wanderpakt_calm_b", 0, "low"),
                  "contact": ("wanderpakt_contact", 180, "low"), "battle_low": ("wanderpakt_battle_low", 110, "medium"),
                  "battle_high": ("wanderpakt_battle_high", 120, "high"), "critical": ("wanderpakt_critical", 154, "high")},
        "lumen": {"display_name": "Prisma-Konklave", "motif": [0, 11, 4, 9], "identity": "fremdartig, präzise, räumlich",
                  "calm_a": ("prisma_calm_a", 96, "low"), "calm_b": ("prisma_calm_b", 96, "low"),
                  "contact": ("prisma_contact", 80, "low"), "battle_low": ("prisma_battle_low", 96, "medium"),
                  "battle_high": ("prisma_battle_high", 120, "high"), "critical": ("prisma_critical", 120, "high")},
    }
    for faction, spec in specs.items():
        tracks: dict[str, list[dict[str, Any]]] = {}
        for state in ("calm_a", "calm_b", "contact", "battle_low", "battle_high", "critical"):
            track_id, bpm, intensity = spec[state]
            # Aliases reuse the same licensed runtime file where the four-stage game director shares a cue.
            source_id, relpath = mappings.get(track_id, ("factory", str(output[track_id])))
            path = str(output[track_id]) if track_id in output else relpath
            track_entry = entry(f"{faction}_{state}", path, source_id, bpm, intensity)
            if source_id == "graveyard":
                duration = float(subprocess.check_output([
                    "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1",
                    str(AUDIO / relpath),
                ], cwd=ROOT, text=True).strip())
                track_entry["loop_end_seconds"] = round(duration, 3)
                track_entry["unmetered"] = True
            tracks[state] = [track_entry]
            extras = {
                ("forge", "battle_high"): [("forge_battle_high_theme_a", "battle_theme_a", "music/kobalt/battle_high_theme_a.ogg")],
                ("drift", "battle_high"): [("drift_battle_high_epic", "epic_fight", "music/wanderpakt/battle_high_epic.ogg")],
                ("lumen", "battle_high"): [
                    ("lumen_battle_high_noisy", "noisy_battle", "music/prisma/battle_high_noisy.ogg"),
                    ("lumen_battle_high_space", "space_battle", "music/prisma/space_battle.ogg"),
                ],
            }.get((faction, state), [])
            for extra_id, extra_source, extra_path in extras:
                extra_entry = entry(extra_id, extra_path, extra_source, 0, "high")
                extra_entry["unmetered"] = True
                extra_entry["loop_end_seconds"] = audio_duration(source_path(extra_source)) * 2.0 if extra_source == "space_battle" else 180.0
                tracks[state].append(extra_entry)
        catalog.setdefault("factions", {}).setdefault(faction, {}).update({
            "display_name": spec["display_name"], "motif": spec["motif"], "identity": spec["identity"],
            "tracks": tracks,
        })
    catalog["global_stingers"] = stingers
    catalog["production_status"] = "curated_cc0_candidate_set_pending_human_listening_review"
    catalog["approval_policy"] = "Human listening approval remains mandatory at 30 seconds, 5 minutes when applicable, and in a real match. CC0 provenance does not imply creative approval."
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Created {len(set(output.values())) + len(stingers)} music/stinger runtime files. All are licensed, but remain pending listening approval.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", action="store_true", required=True)
    parser.add_argument("--overwrite", action="store_true", help="rebuild runtime files from staged sources")
    args = parser.parse_args()
    required = ["ffmpeg", "ffprobe"]
    if any(subprocess.run([x, "-version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode for x in required):
        raise RuntimeError("ffmpeg and ffprobe are required")
    build(overwrite=args.overwrite)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"AUDIO PRODUCTION FAILED: {error}", file=sys.stderr)
        raise SystemExit(2)
