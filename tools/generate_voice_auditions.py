#!/usr/bin/env python3
"""Generate review-only German multi-speaker TTS auditions.

These files are never added to the game catalogs. The pinned model is the
German MLS Piper voice (CC-BY 4.0 training set); each audition uses the same
short command sequence so a human can compare speaker timbres before deciding
whether to replace any of the current Thorsten-Voice candidates.
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import subprocess
import sys
import urllib.request
import wave

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "test-output" / "audio-review" / "voice_options"
MODEL_DIR = REVIEW / "model"
PIPER_RUNTIME = ROOT / "test-output" / "audio-voice-review" / "piper-runtime"
MODEL_FILE = MODEL_DIR / "de_DE-mls-medium.onnx"
MODEL_JSON = MODEL_DIR / "de_DE-mls-medium.onnx.json"
REVISION = "bae641dcb5a608cff81ccaf7ff018baaca1a33e1"
MODEL_SHA256 = "69cd1d2aa5a35839a518966fcc4924b5f93e5f8c948ed0752b1a616ad53f65bf"
BASE_URL = f"https://huggingface.co/rhasspy/piper-voices/resolve/{REVISION}/de/de_DE/mls/medium"
MODEL_URLS = {
    MODEL_FILE: f"{BASE_URL}/de_DE-mls-medium.onnx",
    MODEL_JSON: f"{BASE_URL}/de_DE-mls-medium.onnx.json",
}
SPEAKER_IDS = (4, 21, 53, 91, 147, 203)
AUDITION_TEXT = "Einheit bereit. Auf dem Weg. Feuer frei."
FACTION_PHRASES = {
    "auswahl": "Einheit ausgewählt.",
    "bewegung": "Auf dem Weg!",
    "bestaetigung": "Jawoll, Sir!",
    "angriff": "Feuer frei!",
    "sammler": "Der Sammler ist voll. Rückkehr zur Raffinerie.",
    "arbeit": "Arbeit! Arbeit!",
}


def fetch(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".download")
    request = urllib.request.Request(url, headers={"User-Agent": "SOLARIT-audio-audition/1.0"})
    with urllib.request.urlopen(request, timeout=120) as response, temporary.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
    temporary.replace(destination)


def load_piper():
    if PIPER_RUNTIME.is_dir():
        sys.path.insert(0, str(PIPER_RUNTIME))
    try:
        from piper import PiperVoice, SynthesisConfig
    except ImportError as error:
        raise RuntimeError(
            "Install the review-only tool with: "
            "python -m pip install --target test-output/audio-voice-review/piper-runtime piper-tts==1.8.0"
        ) from error
    return PiperVoice, SynthesisConfig


def main() -> int:
    for path, url in MODEL_URLS.items():
        if not path.is_file():
            fetch(url, path)
    digest = hashlib.sha256(MODEL_FILE.read_bytes()).hexdigest()
    if digest != MODEL_SHA256:
        raise RuntimeError(f"Pinned voice model SHA-256 mismatch: {digest}")

    PiperVoice, SynthesisConfig = load_piper()
    voice = PiperVoice.load(str(MODEL_FILE))
    output_dir = REVIEW / "samples"
    output_dir.mkdir(parents=True, exist_ok=True)
    ffmpeg = os.environ.get("FFMPEG", "ffmpeg")
    for speaker_id in SPEAKER_IDS:
        wav_path = output_dir / f"mls_speaker_{speaker_id:03d}.wav"
        ogg_path = output_dir / f"mls_speaker_{speaker_id:03d}.ogg"
        with wave.open(str(wav_path), "wb") as wav_file:
            voice.synthesize_wav(
                AUDITION_TEXT,
                wav_file,
                syn_config=SynthesisConfig(speaker_id=speaker_id),
            )
        subprocess.run([
            ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-i", str(wav_path),
            "-af", "loudnorm=I=-19:TP=-3:LRA=7", "-ar", "48000", "-ac", "1",
            "-c:a", "libvorbis", "-q:a", "5", str(ogg_path),
        ], check=True)
        wav_path.unlink()
        print(f"created speaker {speaker_id}: {ogg_path.relative_to(ROOT)}")

    # A second audition grid uses identical, frequently heard gameplay lines
    # across every speaker. It is deliberately outside the runtime catalog:
    # the project must not silently assign a faction based on speaker ID.
    faction_output = REVIEW / "faction_comparison"
    faction_samples = faction_output / "samples"
    faction_samples.mkdir(parents=True, exist_ok=True)
    rows: list[str] = []
    for phrase_id, phrase in FACTION_PHRASES.items():
        cells = [f"<th scope=\"row\">{phrase_id.title()}<br><span>{phrase}</span></th>"]
        for speaker_id in SPEAKER_IDS:
            wav_path = faction_samples / f"mls_{speaker_id:03d}_{phrase_id}.wav"
            ogg_path = faction_samples / f"mls_{speaker_id:03d}_{phrase_id}.ogg"
            with wave.open(str(wav_path), "wb") as wav_file:
                voice.synthesize_wav(
                    phrase,
                    wav_file,
                    syn_config=SynthesisConfig(speaker_id=speaker_id),
                )
            subprocess.run([
                ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-i", str(wav_path),
                "-af", "loudnorm=I=-19:TP=-3:LRA=7", "-ar", "48000", "-ac", "1",
                "-c:a", "libvorbis", "-q:a", "5", str(ogg_path),
            ], check=True)
            wav_path.unlink()
            cells.append(
                f"<td><audio controls preload=\"none\" src=\"samples/{ogg_path.name}\"></audio>"
                f"<small>MLS-Sprecher {speaker_id}</small></td>"
            )
        rows.append("<tr>" + "".join(cells) + "</tr>")

    html = """<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>SOLARIT – Fraktionsstimmen im Vergleich</title>
<style>
body{margin:2rem;background:#141718;color:#e8e3d5;font:16px system-ui,sans-serif}h1{color:#e5b868}
p{max-width:1000px;line-height:1.5;color:#bac4bd}.warning{padding:1rem;border:1px solid #b78047;background:#282019}
table{border-collapse:collapse;width:100%;max-width:1500px;margin-top:1.5rem}th,td{border:1px solid #655846;padding:.8rem;text-align:center}
th[scope=row]{text-align:left;min-width:180px}th span{font-weight:400;color:#bbb}audio{width:100%;min-width:150px}small{display:block;margin-top:.3rem;color:#c7b79a}
</style>
<h1>Deutsche Fraktionsstimmen – Timbre-Vergleich</h1>
<p class="warning"><strong>Nur Hörvergleich.</strong> Alle Spalten verwenden dieselben Textzeilen und den gepinnten deutschen MLS-Neural-TTS-Sprecher. Noch keine Stimme ist einer Fraktion zugeordnet oder für den Release freigegeben. Die finalen Einheitenstimmen brauchen eine bewusste menschliche Auswahl und Hörprüfung.</p>
<p>Vergleiche je Zeile die sechs Sprecher. Wähle erst nach dem Hören: ruhig/tief für Kobalt, rau/direkt für Wanderpakt, kühl/kontrolliert für Prisma. Ein Sprecher kann mehrere Zeilen anders betonen; prüfe daher alle vier Situationen.</p>
<table><thead><tr><th>Ereignis</th>""" + "".join(
        f"<th>Option {index} · MLS {speaker_id}</th>"
        for index, speaker_id in enumerate(SPEAKER_IDS, start=1)
    ) + "</tr></thead><tbody>" + "".join(rows) + "</tbody></table>\n"
    (faction_output / "index.html").write_text(html, encoding="utf-8")
    print(f"wrote faction voice comparison: {(faction_output / 'index.html').relative_to(ROOT)}")

    print(f"model_sha256={digest}")
    print("status=audition_only; generated voices are synthetic and not runtime-approved")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
