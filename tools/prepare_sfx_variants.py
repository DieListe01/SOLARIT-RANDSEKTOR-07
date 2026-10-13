#!/usr/bin/env python3
"""Prepare small, licensed weapon/impact variation banks from Kenney CC0 SFX."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SFX = ROOT / "assets/audio/sfx/kenney"
CATALOG = ROOT / "assets/audio/sfx_catalog.json"
URL = "https://kenney.nl/assets/sci-fi-sounds"

SOURCES = {
    "ballistic_light_shot": "laserSmall_000.ogg", "ballistic_heavy_shot": "laserLarge_000.ogg",
    "autocannon_shot": "laserSmall_000.ogg", "artillery_shot": "laserLarge_000.ogg",
    "missile_shot": "laserLarge_000.ogg", "energy_shot": "laserSmall_000.ogg",
    "siege_shot": "laserLarge_000.ogg", "special_shot": "laserLarge_000.ogg",
    "ballistic_light_impact": "impactMetal_000.ogg", "ballistic_heavy_impact": "impactMetal_002.ogg",
    "autocannon_impact": "impactMetal_000.ogg", "artillery_impact": "impactMetal_002.ogg",
    "missile_impact": "impactMetal_002.ogg", "energy_impact": "impactMetal_000.ogg",
    "siege_impact": "impactMetal_002.ogg", "special_impact": "impactMetal_000.ogg",
}
VARIANTS = ("", "asetrate=48000*0.94,aresample=48000", "asetrate=48000*1.06,aresample=48000")


def main() -> None:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    for cue, source_name in SOURCES.items():
        source = SFX / source_name
        if not source.is_file():
            raise FileNotFoundError(source)
        rows = []
        for number, audio_filter in enumerate(VARIANTS, 1):
            relative = f"variants/{cue}_{number:02d}.ogg"
            output = SFX / relative
            output.parent.mkdir(parents=True, exist_ok=True)
            command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source)]
            if audio_filter:
                command += ["-af", audio_filter]
            command += ["-ar", "48000", "-c:a", "libvorbis", "-q:a", "5", str(output)]
            subprocess.run(command, check=True, cwd=ROOT)
            rows.append({
                "id": f"kenney_{cue}_{number:02d}",
                "path": f"res://assets/audio/sfx/kenney/{relative}",
                "author": "Kenney", "source": "Kenney Sci-Fi Sounds", "source_url": URL,
                "processing": "48 kHz runtime conversion; subtle pitch variant" if number > 1 else "48 kHz runtime conversion",
                "asset_status": "candidate", "human_listening_approval": "pending",
                "license": {"name": "CC0 1.0", "status": "cleared", "commercial_use": True,
                             "attribution": "Kenney (optional)"},
            })
        catalog["cues"][cue] = rows
    catalog["weapon_variants"] = "Three derived CC0 variants per weapon-family shot and impact cue; subtle pitch shifts only; pending in-game listening approval."
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {len(SOURCES)} weapon/impact candidate banks with three variants each.")


if __name__ == "__main__":
    main()
