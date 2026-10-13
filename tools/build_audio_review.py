#!/usr/bin/env python3
"""Build a local, browsable listening review page for SOLARIT audio candidates."""
from __future__ import annotations

import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "test-output" / "audio-review" / "index.html"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def rel_asset(path: str) -> str:
    return "../../" + path.removeprefix("res://")


def card(title: str, path: str, detail: str = "") -> str:
    safe_title = html.escape(title)
    safe_path = html.escape(path, quote=True)
    safe_detail = html.escape(detail)
    return (f'<article class="card"><h3>{safe_title}</h3>'
            f'<p class="detail">{safe_detail}</p>'
            f'<audio controls preload="none" src="{safe_path}"></audio></article>')


def build() -> None:
    music = read_json(ROOT / "assets/audio/music_catalog.json")
    voices = read_json(ROOT / "assets/audio/voice/voice_catalog.json")
    sfx = read_json(ROOT / "assets/audio/sfx_catalog.json")
    parts = ["""<!doctype html><html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>SOLARIT · Audio-Abnahme</title>
<style>
:root{color-scheme:dark;--bg:#101719;--panel:#202a2b;--line:#56615d;--mint:#69dfc5;--gold:#ddb36f;--fg:#e6e6dc}
body{margin:auto;max-width:1180px;padding:28px;background:var(--bg);color:var(--fg);font:16px/1.5 system-ui,sans-serif}
h1,h2{color:var(--gold)}h2{margin-top:36px}h3{font-size:1rem;color:var(--mint);margin:0}
.notice{padding:16px;border:1px solid #9b7544;background:#241f19}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(290px,1fr));gap:12px;margin-top:12px}
.card{padding:14px;background:var(--panel);border:1px solid var(--line);border-radius:5px}.detail{min-height:24px;color:#b8c2bc;margin:6px 0;font-size:.9rem}
audio{width:100%;margin-top:8px}a{color:var(--mint)}small{color:#a9b2ad}
</style></head><body><h1>SOLARIT — Hörabnahme der Audio-Kandidaten</h1>
<div class="notice"><strong>Alle Dateien auf dieser Seite sind Kandidaten.</strong> Musik, Sprachsamples und SFX sind technisch eingebunden, aber noch nicht menschlich abgenommen. Bitte auf Klang, Wiederholungen, Lautheit und Wirkung im Spiel achten. Der lange Gesamtmix enthält kurze Ausschnitte; die Einzeldateien unten erlauben direkten Vergleich. <br><a href="SOLARIT-Audio-Abnahme-Preview.ogg">Gesamtvorschau abspielen</a> · <a href="SOLARIT-Audio-Abnahme-Preview.txt">Zeitindex öffnen</a></div>"""]

    title = music.get("title_track", {})
    if title:
        parts.append('<h2>Titelmusik</h2><div class="grid">' + card(
            str(title.get("id", "Titel")), rel_asset(str(title.get("path", ""))),
            f"{title.get('bpm', '?')} BPM · {title.get('source', {}).get('author', 'Quelle offen')} · Abnahme ausstehend") + "</div>")

    names = {"forge": "Kobalt-Konsortium", "drift": "Wanderpakt", "lumen": "Prisma-Konklave"}
    state_names = {"calm_a": "Ruhe A", "calm_b": "Ruhe B / Wirtschaft", "contact": "Feindkontakt",
                   "battle_low": "Gefecht, Aufbau", "battle_high": "Gefecht, intensiv", "critical": "Kritisch"}
    for faction, data in music.get("factions", {}).items():
        cards = []
        for state, tracks in data.get("tracks", {}).items():
            for track in tracks:
                cards.append(card(state_names.get(state, state), rel_asset(str(track.get("path", ""))),
                                   f"{track.get('bpm', '?')} BPM · {track.get('source', {}).get('author', 'Quelle offen')} · Kandidat"))
        parts.append(f"<h2>Musik · {html.escape(names.get(faction, faction))}</h2><div class=\"grid\">" + "".join(cards) + "</div>")

    stingers = music.get("global_stingers", {})
    if stingers:
        parts.append("<h2>Musik-Stinger</h2><div class=\"grid\">" + "".join(
            card(key.replace("_", " ").title(), rel_asset(str(item.get("path", ""))),
                 f"{item.get('source', {}).get('author', 'Quelle offen')} · Kandidat")
            for key, item in stingers.items()) + "</div>")

    voice_cards = []
    for faction, data in voices.get("factions", {}).items():
        for event, lines in data.get("lines", {}).items():
            for line in lines:
                voice_cards.append(card(f"{names.get(faction, faction)} · {event} · {line.get('text', '')}",
                                        rel_asset(str(line.get("asset", ""))),
                                        "Piper Neural-TTS · synthetische Kandidatenstimme · Abnahme ausstehend"))
    for line in voices.get("system_lines", []):
        if isinstance(line, dict) and line.get("asset"):
            voice_cards.append(card(f"System · {line.get('event', '')} · {line.get('text', '')}",
                                    rel_asset(str(line["asset"])), "Piper Neural-TTS · Kandidat"))
    parts.append("<h2>Sprachsamples</h2><small>Die Fraktionsvarianten stammen aus demselben deutschen TTS-Modell. Sie sind noch keine Studioaufnahmen oder unabhängig gecasteten Stimmen.</small><div class=\"grid\">" + "".join(voice_cards) + "</div>")

    sfx_cards = []
    for cue, clips in sfx.get("cues", {}).items():
        for clip in clips:
            sfx_cards.append(card(f"{cue.replace('_', ' ').title()} · {clip.get('id', '')}",
                                  rel_asset(str(clip.get("path", ""))),
                                  f"{clip.get('source', 'Quelle')} · CC0-Kandidat · Abnahme ausstehend"))
    parts.append("<h2>Soundeffekte</h2><div class=\"grid\">" + "".join(sfx_cards) + "</div>")
    parts.append("<p><small>Technische Integrations- und Formatprüfungen sind bestanden. Das ersetzt keine Hörabnahme und gibt keine Veröffentlichung frei.</small></p></body></html>")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(parts), encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    build()
