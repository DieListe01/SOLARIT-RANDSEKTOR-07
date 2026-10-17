#!/usr/bin/env python3
"""Build a local, browsable listening review page for SOLARIT audio candidates."""
from __future__ import annotations

import html
import json
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "test-output" / "audio-review" / "index.html"
ALTERNATIVES = [
    {"title": "Outer Space · Battle Intro", "file": "outer_space_battle_intro.ogg", "source_file": "06_battle_in_space_intro.ogg",
     "folder": "outer_space_music_pack", "author": "Leonardo Paz (leohpaz)", "url": "https://opengameart.org/content/outer-space-music-pack",
     "detail": "CC-BY 4.0 · Leonardo Paz (leohpaz) · 44.77 s · orchestrales Weltraumgefecht · Intro, nur Hörvergleich"},
    {"title": "Outer Space · Battle Loop", "file": "outer_space_battle_loop.ogg", "source_file": "06_battle_in_space_loop.ogg",
     "folder": "outer_space_music_pack", "author": "Leonardo Paz (leohpaz)", "url": "https://opengameart.org/content/outer-space-music-pack",
     "detail": "CC-BY 4.0 · Leonardo Paz (leohpaz) · 44.77 s · orchestrales Weltraumgefecht · Loop, nur Hörvergleich"},
    {"title": "Dark Sci-Fi · Title", "file": "dark_sci_fi_title.mp3", "source_file": "title.mp3",
     "folder": "dark_sci_fi_pack", "author": "SRG774", "url": "https://opengameart.org/content/dark-sci-fi-audio-pack",
     "detail": "CC0 · 4:22 · Menü-/Weltraumstimmung · Zusatzkandidat, nicht im Spiel aktiv"},
    {"title": "Dark Sci-Fi · Sector", "file": "dark_sci_fi_sector.mp3", "source_file": "sector.mp3",
     "folder": "dark_sci_fi_pack", "author": "SRG774", "url": "https://opengameart.org/content/dark-sci-fi-audio-pack",
     "detail": "CC0 · 56.9 s · fremdartige Erkundung · Zusatzkandidat, nicht im Spiel aktiv"},
    {"title": "Dark Sci-Fi · Airy", "file": "dark_sci_fi_airy.mp3", "source_file": "airy.mp3",
     "folder": "dark_sci_fi_pack", "author": "SRG774", "url": "https://opengameart.org/content/dark-sci-fi-audio-pack",
     "detail": "CC0 · 64 s · räumliche Atmosphäre · Zusatzkandidat, nicht im Spiel aktiv"},
    {"title": "Dark Sci-Fi · Pulse", "file": "dark_sci_fi_pulse.mp3", "source_file": "pulse.mp3",
     "folder": "dark_sci_fi_pack", "author": "SRG774", "url": "https://opengameart.org/content/dark-sci-fi-audio-pack",
     "detail": "CC0 · 71.1 s · rhythmischer Puls · Zusatzkandidat, nicht im Spiel aktiv"},
    {"title": "Dark Sci-Fi · Urgent", "file": "dark_sci_fi_urgent.mp3", "source_file": "urgent.mp3",
     "folder": "dark_sci_fi_pack", "author": "SRG774", "url": "https://opengameart.org/content/dark-sci-fi-audio-pack",
     "detail": "CC0 · 56.9 s · dringliche Kampfspannung · Zusatzkandidat, nicht im Spiel aktiv"},
    {"title": "Dark Sci-Fi · Transmission", "file": "dark_sci_fi_transmission.mp3", "source_file": "transmission.mp3",
     "folder": "dark_sci_fi_pack", "author": "SRG774", "url": "https://opengameart.org/content/dark-sci-fi-audio-pack",
     "detail": "CC0 · 94 s · finsterer Übergang/Stinger · Zusatzkandidat, nicht im Spiel aktiv"},
    {"title": "Dark Sci-Fi · Victory", "file": "dark_sci_fi_victory.mp3", "source_file": "victory.mp3",
     "folder": "dark_sci_fi_pack", "author": "SRG774", "url": "https://opengameart.org/content/dark-sci-fi-audio-pack",
     "detail": "CC0 · 5.9 s · Sieg-Stinger · Zusatzkandidat, nicht im Spiel aktiv"},
]
SFX_ALTERNATIVES = [
    {"title": "Generator Loop · Raffinerie/Kraftwerk", "file": "generator_loop.wav",
     "source_file": "opengameart_bart_generator_loop.wav", "author": "bart",
     "url": "https://opengameart.org/content/steam-boiler-sound-loop",
     "detail": "CC0 · 22.15 s Stereo-WAV · Generator-/Kesselbetrieb · noch nicht im Spiel aktiv"},
    {"title": "Long Sci-Fi Sting · Alarm/Intro", "file": "long_scifi_sting.ogg",
     "source_file": "opengameart_fupi_long_scifi_sting.ogg", "author": "Fupi",
     "url": "https://opengameart.org/content/long-sci-fi-sting",
     "detail": "CC0 · 12 s Stereo-OGG · fremdartiger Labor-/Eintritts-Sting · noch nicht im Spiel aktiv"},
    {"title": "Engine Sound 1 · Fahrzeugmotor", "file": "pauliuw_engine_1.mp3",
     "source_file": "engine_sound.mp3", "folder": "engine_sounds_pauliuw", "author": "pauliuw",
     "url": "https://opengameart.org/content/engine-sounds2",
     "detail": "CC0 · 20,712 s · MP3, 48 kHz Stereo · Motoraufnahme · nur Hörvergleich, nicht im Spiel aktiv"},
    {"title": "Engine Sound 2 · Fahrzeugmotor", "file": "pauliuw_engine_2.mp3",
     "source_file": "engine_sound_1.mp3", "folder": "engine_sounds_pauliuw", "author": "pauliuw",
     "url": "https://opengameart.org/content/engine-sounds2",
     "detail": "CC0 · 20,712 s · MP3, 48 kHz Stereo · zweite Motoraufnahme · nur Hörvergleich, nicht im Spiel aktiv"},
]
VOICE_AUDITION_SPEAKERS = (4, 21, 53, 91, 147, 203)
VOICE_MODEL_CARD = "https://huggingface.co/rhasspy/piper-voices/blob/bae641dcb5a608cff81ccaf7ff018baaca1a33e1/de/de_DE/mls/medium/MODEL_CARD"
SFX_60_SOURCE = ROOT / "tools/audio_sources/candidates/60_cc0_sci_fi_sfx/60-sci-fi-sfx.zip"
SFX_60_REVIEW = OUT.parent / "sfx_60_cc0"
SFX_60_URL = "https://opengameart.org/content/60-cc0-sci-fi-sfx"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def rel_asset(path: str) -> str:
    return "../../" + path.removeprefix("res://")


def card(title: str, path: str, detail: str = "", source_url: str = "") -> str:
    safe_title = html.escape(title)
    safe_path = html.escape(path, quote=True)
    safe_detail = html.escape(detail)
    source_link = (f' · <a href="{html.escape(source_url, quote=True)}" target="_blank" rel="noreferrer">Quelle/Lizenz</a>'
                   if source_url.startswith("https://") else "")
    return (f'<article class="card"><h3>{safe_title}</h3>'
            f'<p class="detail">{safe_detail}{source_link}</p>'
            f'<audio controls preload="none" src="{safe_path}"></audio></article>')


def voice_rows(voices: dict) -> list[tuple[str, dict]]:
    """Return every playable faction and system voice entry in catalog order."""
    rows: list[tuple[str, dict]] = []
    for faction, data in voices.get("factions", {}).items():
        for event, lines in data.get("lines", {}).items():
            rows.extend((faction, {**line, "event": event}) for line in lines if line.get("asset"))
    system = voices.get("system", {})
    if isinstance(system, dict):
        for event, lines in system.items():
            rows.extend(("neutral", {**line, "event": event}) for line in lines if line.get("asset"))
    # Older schema is kept readable for review archives.
    for line in voices.get("system_lines", []):
        if isinstance(line, dict) and line.get("asset"):
            rows.append(("neutral", line))
    return rows


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
<div class="notice"><strong>Alle Dateien auf dieser Seite sind Kandidaten.</strong> Musik, Sprachsamples und SFX sind technisch eingebunden, aber noch nicht menschlich abgenommen. Bitte die jeweilige Prüftiefe beachten: Musik nach 30 Sekunden, bei fünf Minuten und im Match; Stimmen auf Verständlichkeit, Aussprache, Fraktionscharakter, Wiederholung und Match-Mix; SFX auf Ereignispassung, Lautheit und Match-Mix. Eine Freigabe wird erst nach menschlichem Hören dokumentiert. Der lange Gesamtmix enthält kurze Ausschnitte; die Einzeldateien unten erlauben direkten Vergleich. <br><a href="SOLARIT-Audio-Abnahme-Preview.ogg">Gesamtvorschau abspielen</a> · <a href="SOLARIT-Audio-Abnahme-Preview.txt">Zeitindex öffnen</a></div>"""]

    title = music.get("title_track", {})
    if title:
        parts.append('<h2>Titelmusik</h2><div class="grid">' + card(
            str(title.get("id", "Titel")), rel_asset(str(title.get("path", ""))),
            f"{title.get('bpm', '?')} BPM · {title.get('source', {}).get('author', 'Quelle offen')} · {title.get('asset_status', 'missing')} / {title.get('human_listening_approval', 'pending')}",
            str(title.get("source", {}).get("url", ""))) + "</div>")

    names = {"forge": "Kobalt-Konsortium", "drift": "Wanderpakt", "lumen": "Prisma-Konklave"}
    state_names = {"calm_a": "Ruhe A", "calm_b": "Ruhe B / Wirtschaft", "contact": "Feindkontakt",
                   "battle_low": "Gefecht, Aufbau", "battle_high": "Gefecht, intensiv", "critical": "Kritisch"}
    for faction, data in music.get("factions", {}).items():
        cards = []
        for state, tracks in data.get("tracks", {}).items():
            for track in tracks:
                source_title = track.get("source", {}).get("title", "")
                source_prefix = f"{source_title} · " if source_title else ""
                tempo_label = "ohne festes Taktmaß" if track.get("unmetered", False) else f"{track.get('bpm', '?')} BPM"
                cards.append(card(state_names.get(state, state), rel_asset(str(track.get("path", ""))),
                                   f"{source_prefix}{tempo_label} · {track.get('source', {}).get('author', 'Quelle offen')} · {track.get('asset_status', 'missing')} / {track.get('human_listening_approval', 'pending')}",
                                   str(track.get("source", {}).get("url", ""))))
        parts.append(f"<h2>Musik · {html.escape(names.get(faction, faction))}</h2><div class=\"grid\">" + "".join(cards) + "</div>")

    stingers = music.get("global_stingers", {})
    if stingers:
        parts.append("<h2>Musik-Stinger</h2><div class=\"grid\">" + "".join(
            card(key.replace("_", " ").title(), rel_asset(str(item.get("path", ""))),
                 f"{item.get('source', {}).get('author', 'Quelle offen')} · {item.get('asset_status', 'missing')} / {item.get('human_listening_approval', 'pending')}",
                 str(item.get("source", {}).get("url", "")))
            for key, item in stingers.items()) + "</div>")

    voice_cards = []
    for faction, line in voice_rows(voices):
        label = names.get(faction, "System") if faction != "neutral" else "System"
        status = f"{line.get('asset_status', 'missing')} / {line.get('human_listening_approval', line.get('approval', 'pending'))}"
        voice_cards.append(card(f"{label} · {line.get('event', '')} · {line.get('text', '')}",
                                rel_asset(str(line.get("asset", ""))),
                                f"Piper Neural-TTS · Kandidat · {status}",
                                str(line.get("source", {}).get("url", ""))))
    parts.append("<h2>Sprachsamples</h2><small>Die Fraktionsvarianten stammen aus demselben deutschen TTS-Modell. Sie sind spielbar, aber keine Studioaufnahmen oder unabhängig gecasteten Stimmen. System-/Warnstimmen sind vollständig enthalten.</small><div class=\"grid\">" + "".join(voice_cards) + "</div>")

    sfx_cards = []
    for cue, clips in sfx.get("cues", {}).items():
        for clip in clips:
            sfx_cards.append(card(f"{cue.replace('_', ' ').title()} · {clip.get('id', '')}",
                                  rel_asset(str(clip.get("path", ""))),
                                  f"{clip.get('source', 'Quelle')} · {clip.get('asset_status', 'missing')} / {clip.get('human_listening_approval', 'pending')}",
                                  str(clip.get("source_url", ""))))
    parts.append("<h2>Soundeffekte</h2><div class=\"grid\">" + "".join(sfx_cards) + "</div>")
    if SFX_60_SOURCE.is_file():
        SFX_60_REVIEW.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(SFX_60_SOURCE) as archive:
            members = [item for item in archive.infolist()
                       if not item.is_dir() and Path(item.filename).name.lower().endswith(".ogg")
                       and Path(item.filename).name.startswith("sfx_")]
            for item in members:
                filename = Path(item.filename).name
                if filename != item.filename or not filename[4:-4].replace("a", "").replace("b", "").replace("c", "").replace("d", "").isdigit():
                    raise ValueError(f"Unexpected file in CC0 SFX archive: {item.filename}")
                (SFX_60_REVIEW / filename).write_bytes(archive.read(item))
        candidate_cards = [card(
            f"CC0-Sci-Fi-SFX · {path.stem}", f"sfx_60_cc0/{path.name}",
            "rubberduck · 60-clip Vergleichspaket · CC0 · nur Hörkandidat, nicht im Spiel aktiv",
            SFX_60_URL,
        ) for path in sorted(SFX_60_REVIEW.glob("sfx_*.ogg"))]
        if len(candidate_cards) != 60:
            raise ValueError(f"Expected 60 extracted CC0 SFX review clips, got {len(candidate_cards)}")
        parts.append("<h2>Zusätzliche CC0-Sci-Fi-SFX · 60 Hörkandidaten, nicht aktiv</h2><div class=\"grid\">" + "".join(candidate_cards) + "</div>")
    alternate_cards = []
    for item in ALTERNATIVES:
        candidate = OUT.parent / "alternatives" / item["file"]
        source = ROOT / "tools/audio_sources/candidates" / item.get("folder", "") / item["source_file"]
        if source.is_file() and not candidate.is_file():
            candidate.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, candidate)
        if candidate.is_file():
            alternate_cards.append(card(item["title"], "alternatives/" + item["file"],
                                         item["detail"] + " · Hörfreigabe ausstehend",
                                         item["url"]))
    if alternate_cards:
        parts.append("<h2>Zusätzliche lizenzierte Musikkandidaten · Vergleich, nicht aktiv</h2><div class=\"grid\">" + "".join(alternate_cards) + "</div>")
    sfx_alternative_cards = []
    sfx_candidate_root = ROOT / "tools/audio_sources/candidates"
    sfx_review_root = OUT.parent / "sfx_alternatives"
    for item in SFX_ALTERNATIVES:
        source = sfx_candidate_root / item.get("folder", "") / item["source_file"]
        candidate = sfx_review_root / item["file"]
        if source.is_file() and not candidate.is_file():
            candidate.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, candidate)
        if candidate.is_file():
            sfx_alternative_cards.append(card(
                item["title"], "sfx_alternatives/" + item["file"],
                item["detail"] + " · Hörfreigabe ausstehend",
                item["url"],
            ))
    if sfx_alternative_cards:
        parts.append("<h2>Zusätzliche CC0-Soundkandidaten · Vergleich, nicht aktiv</h2><div class=\"grid\">" + "".join(sfx_alternative_cards) + "</div>")
    voice_option_cards = []
    for speaker_id in VOICE_AUDITION_SPEAKERS:
        path = OUT.parent / "voice_options" / "samples" / f"mls_speaker_{speaker_id:03d}.ogg"
        if path.is_file():
            voice_option_cards.append(card(
                f"Mehrsprecher-Stimmprobe {speaker_id:03d}",
                f"voice_options/samples/mls_speaker_{speaker_id:03d}.ogg",
                "‚Einheit bereit. Auf dem Weg. Feuer frei.‘ · gleiche Befehlszeile zum Stimmenvergleich · CC BY 4.0 · Hörkandidat, nicht integriert",
                VOICE_MODEL_CARD,
            ))
    if voice_option_cards:
        parts.append("<h2>Alternative Fraktionsstimmen · identische Befehlszeile, nicht aktiv</h2><div class=\"grid\">" + "".join(voice_option_cards) + "</div>")
    faction_voice_review = OUT.parent / "voice_options" / "faction_comparison" / "index.html"
    if faction_voice_review.is_file():
        parts.append(
            '<h2>Fraktionsstimmen im direkten Vergleich</h2>'
            '<p>Sechs deutsche Mehrsprecher-Timbres sprechen dieselben sechs Einheitenbefehle, darunter „Jawoll, Sir!“, „Auf dem Weg!“ und „Arbeit! Arbeit!“. '
            '<a href="voice_options/faction_comparison/index.html">Vergleich öffnen</a>. '
            'Nur Hörkandidaten; noch keiner Fraktion zugeordnet.</p>'
        )
    parts.append("<p><small>Technische Integrations- und Formatprüfungen sind bestanden. Das ersetzt keine Hörabnahme und gibt keine Veröffentlichung frei.</small></p></body></html>")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(parts), encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    build()
