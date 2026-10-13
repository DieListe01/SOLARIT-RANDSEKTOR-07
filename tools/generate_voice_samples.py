#!/usr/bin/env python3
"""Generate provisional German unit-response clips from a licensed Piper voice.

This is an offline, reproducible candidate-production step. It does not mark
clips approved and does not replace the listening/release review. The voice
model itself is supplied by the operator and is deliberately not bundled.
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
CATALOG = AUDIO / "voice" / "voice_catalog.json"
VOICE_MASTERS = ROOT / "test-output" / "audio-review" / "masters" / "voice"

# Thorsten-Voice emotional model speaker IDs (dataset and model card are CC0).
FACTION_SPEAKERS = {"forge": 4, "drift": 1, "lumen": 7}
SYSTEM_SPEAKER = 4


def run(command: list[str]) -> None:
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        detail = result.stderr.decode("utf-8", "replace")[-3000:]
        raise RuntimeError(f"Command failed ({result.returncode}): {' '.join(command)}\n{detail}")


def synthesize(model: Path, config: Path, overwrite: bool) -> int:
    try:
        from piper import PiperVoice, SynthesisConfig
    except ImportError as error:
        raise RuntimeError("Install piper-tts in the local production environment before generating voices") from error

    catalog: dict[str, Any] = json.loads(CATALOG.read_text(encoding="utf-8"))
    voice = PiperVoice.load(model, config_path=config, use_cuda=False)
    generated = 0
    with tempfile.TemporaryDirectory(prefix="solarit_voice_") as temporary:
        temp_dir = Path(temporary)
        for faction, faction_data in catalog.get("factions", {}).items():
            speaker = FACTION_SPEAKERS.get(faction, SYSTEM_SPEAKER)
            synthesis = SynthesisConfig(speaker_id=speaker, length_scale=0.94 if faction == "drift" else 1.0)
            for event, lines in faction_data.get("lines", {}).items():
                for index, line in enumerate(lines, start=1):
                    line_id = str(line.get("id", f"{faction}_{event}_{index:02d}"))
                    if not str(line.get("text", "")).strip():
                        raise ValueError(f"{line_id}: voice line has no text")
                    output = AUDIO / "voice" / faction / f"{event}_{index:02d}.ogg"
                    if output.exists() and not overwrite:
                        if line.get("asset") == "res://" + output.relative_to(ROOT).as_posix():
                            continue
                        raise FileExistsError(f"Refusing to overwrite {output}; use --overwrite")
                    output.parent.mkdir(parents=True, exist_ok=True)
                    master = temp_dir / f"{line_id}.wav"
                    with master.open("wb") as target:
                        import wave

                        with wave.open(target, "wb") as wav:
                            wav.setframerate(voice.config.sample_rate)
                            wav.setsampwidth(2)
                            wav.setnchannels(1)
                            for chunk in voice.synthesize(str(line["text"]), synthesis):
                                wav.writeframes(chunk.audio_int16_bytes)
                    filters = {
                        "forge": "highpass=f=115,lowpass=f=6800,acompressor=threshold=-20dB:ratio=2.2:attack=8:release=90,volume=1.2",
                        "drift": "highpass=f=100,lowpass=f=7600,acompressor=threshold=-19dB:ratio=2.4:attack=5:release=75,volume=1.1",
                        "lumen": "highpass=f=160,lowpass=f=7800,acompressor=threshold=-21dB:ratio=2:attack=8:release=90,volume=1.15",
                    }
                    VOICE_MASTERS.mkdir(parents=True, exist_ok=True)
                    final_master = VOICE_MASTERS / f"{line_id}.wav"
                    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(master),
                         "-af", f"{filters.get(faction, filters['forge'])},aresample=48000", "-ar", "48000",
                         "-c:a", "pcm_s24le", str(final_master)])
                    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(final_master),
                         "-c:a", "libvorbis", "-q:a", "5", str(output)])
                    line["asset"] = "res://" + output.relative_to(ROOT).as_posix()
                    line["asset_state"] = "generated_neural_tts_pending_review"
                    line["asset_status"] = "candidate"
                    line["approval"] = "pending"
                    line["source"] = {
                        "name": "Thorsten-Voice / Piper thorsten_emotional (speaker variant)",
                        "url": "https://huggingface.co/rhasspy/piper-voices/tree/v1.0.0/de/de_DE/thorsten_emotional/medium",
                        "model_card": "https://huggingface.co/rhasspy/piper-voices/blob/v1.0.0/de/de_DE/thorsten_emotional/medium/MODEL_CARD",
                        "license": "CC0 1.0 (Thorsten-Voice dataset)",
                        "speaker_id": speaker,
                        "processing": "German neural TTS; faction response shaping; mono OGG, 48 kHz runtime resample",
                    }
                    line["license"] = {"name": "CC0 1.0", "status": "cleared", "commercial_use": True,
                                        "attribution": "Thorsten-Voice dataset (optional); Piper model card terms apply"}
                    line["human_listening_approval"] = "pending"
                    generated += 1
        for event, lines in catalog.get("system", {}).items():
            for index, line in enumerate(lines, start=1):
                line_id = str(line.get("id", f"neutral_{event}_{index:02d}"))
                output = AUDIO / "voice" / "neutral" / f"{event}_{index:02d}.ogg"
                if output.exists() and not overwrite:
                    if line.get("asset") == "res://" + output.relative_to(ROOT).as_posix():
                        continue
                    raise FileExistsError(f"Refusing to overwrite {output}; use --overwrite")
                output.parent.mkdir(parents=True, exist_ok=True)
                master = temp_dir / f"{line_id}.wav"
                with master.open("wb") as target:
                    import wave

                    with wave.open(target, "wb") as wav:
                        wav.setframerate(voice.config.sample_rate)
                        wav.setsampwidth(2)
                        wav.setnchannels(1)
                        for chunk in voice.synthesize(str(line["text"]), SynthesisConfig(speaker_id=SYSTEM_SPEAKER)):
                            wav.writeframes(chunk.audio_int16_bytes)
                VOICE_MASTERS.mkdir(parents=True, exist_ok=True)
                final_master = VOICE_MASTERS / f"{line_id}.wav"
                run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(master), "-af",
                     "highpass=f=130,lowpass=f=7200,acompressor=threshold=-20dB:ratio=2:attack=8:release=90,aresample=48000",
                     "-ar", "48000", "-c:a", "pcm_s24le", str(final_master)])
                run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(final_master),
                     "-c:a", "libvorbis", "-q:a", "5", str(output)])
                line["asset"] = "res://" + output.relative_to(ROOT).as_posix()
                line["asset_state"] = "generated_neural_tts_pending_review"
                line["asset_status"] = "candidate"
                line["approval"] = "pending"
                line["source"] = {"name": "Thorsten-Voice / Piper thorsten_emotional", "url": "https://huggingface.co/rhasspy/piper-voices/tree/v1.0.0/de/de_DE/thorsten_emotional/medium",
                                  "license": "CC0 1.0 (Thorsten-Voice dataset)", "speaker_id": SYSTEM_SPEAKER}
                line["license"] = {"name": "CC0 1.0", "status": "cleared", "commercial_use": True,
                                   "attribution": "Thorsten-Voice dataset (optional); Piper model card terms apply"}
                line["human_listening_approval"] = "pending"
                generated += 1
    catalog["recordings_status"] = "118_neural_tts_candidates_pending_human_review"
    catalog["voice_engine"] = {
        "name": "Piper neural TTS",
        "model": "thorsten_emotional medium",
        "model_license": "CC0 1.0 (voice dataset)",
        "model_url": "https://huggingface.co/rhasspy/piper-voices/tree/v1.0.0/de/de_DE/thorsten_emotional/medium",
        "generated_date": __import__("datetime").date.today().isoformat(),
        "status": "candidate; human review required; not a substitute for studio-recorded faction actors",
        "speaker_profiles": {"forge": 4, "drift": 1, "lumen": 7, "neutral": SYSTEM_SPEAKER},
    }
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {generated} German speech candidates; all remain pending human review.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()
    return synthesize(args.model, args.config, args.overwrite)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"VOICE GENERATION FAILED: {error}", file=sys.stderr)
        raise SystemExit(2)
