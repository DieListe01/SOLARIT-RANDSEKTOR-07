"""Build the reviewed, text-first voice line catalog; recordings are added separately."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

FACTIONS = {
    "forge": {
        "name": "Kobalt-Konsortium",
        "lines": {
            "select": ["Bereit.", "Kommandokanal offen.", "Einheit wartet.", "Bereit für Befehle."],
            "move": ["Unterwegs.", "Route bestätigt.", "Position wird angefahren.", "Bewege mich zum Ziel."],
            "attack": ["Ziel erfasst.", "Angriff beginnt.", "Feuer frei.", "Ziel wird bekämpft."],
            "damage": ["Panzerung beschädigt.", "Strukturschaden bestätigt.", "Einheit beschädigt."],
            "critical": ["Kritischer Schaden.", "Kampffähigkeit gefährdet."],
            "success": ["Position erreicht.", "Auftrag ausgeführt."],
            "harvester_select": ["Erntesystem online.", "Sammler bereit.", "Fördersystem einsatzbereit."],
            "harvest_start": ["Solaritabbau beginnt.", "Erntesystem aktiviert."],
            "harvest_full": ["Laderaum fast voll.", "Speicherkapazität erreicht."],
            "harvest_return": ["Rückkehr zur Raffinerie.", "Ladung wird zur Raffinerie gebracht."],
            "harvest_unload": ["Solarit wird übertragen.", "Entladung läuft."],
            "harvest_danger": ["Sammler unter Beschuss.", "Ernteeinheit gefährdet."],
        },
    },
    "drift": {
        "name": "Wanderpakt",
        "lines": {
            "select": ["Was liegt an?", "Bin bereit.", "Sag wohin.", "Wir hören."],
            "move": ["Wir rollen.", "Schon unterwegs.", "Los geht's.", "Machen wir uns auf."],
            "attack": ["Da ist unser Ziel.", "Draufhalten.", "Jetzt wird's laut.", "Packen wir sie."],
            "damage": ["Wir kassieren!", "Panzerung hält nicht mehr!", "Das hat gesessen."],
            "critical": ["Das wird eng.", "Wir müssen hier raus!"],
            "success": ["Geschafft.", "Platz gehört uns."],
            "harvester_select": ["Sammler läuft.", "Na, dann holen wir was.", "Erntemaschine bereit."],
            "harvest_start": ["Wir holen das Zeug.", "Sammler läuft."],
            "harvest_full": ["Laderaum ist voll.", "Mehr passt nicht rein."],
            "harvest_return": ["Ab zurück zur Raffinerie.", "Wir bringen die Ladung heim."],
            "harvest_unload": ["Abladen, dann weiter.", "Ladung geht rüber."],
            "harvest_danger": ["Sammler unter Beschuss!", "Die Erntemaschine braucht Deckung!"],
        },
    },
    "lumen": {
        "name": "Prisma-Konklave",
        "lines": {
            "select": ["Verbindung hergestellt.", "System bereit.", "Befehlskanal aktiv.", "Anweisung erwartet."],
            "move": ["Vektor gesetzt.", "Navigation aktiv.", "Koordinaten bestätigt.", "Kurs wird ausgeführt."],
            "attack": ["Zielpriorität gesetzt.", "Feuersequenz gestartet.", "Eliminierung eingeleitet.", "Zielanalyse abgeschlossen."],
            "damage": ["Integritätsverlust.", "Strukturschaden registriert.", "Schutzmatrix beeinträchtigt."],
            "critical": ["Integrität kritisch.", "Systemstabilität gefährdet."],
            "success": ["Position bestätigt.", "Aufgabe abgeschlossen."],
            "harvester_select": ["Extraktionseinheit bereit.", "Erntesystem online.", "Sammlersystem verbunden."],
            "harvest_start": ["Extraktionssequenz gestartet.", "Solarit-Erfassung aktiv."],
            "harvest_full": ["Ladekapazität nahezu erreicht.", "Speichergrenze erreicht."],
            "harvest_return": ["Rückkehrvektor zur Raffinerie gesetzt.", "Transportsequenz eingeleitet."],
            "harvest_unload": ["Solarittransfer läuft.", "Entladesequenz aktiv."],
            "harvest_danger": ["Sammlereinheit wird angegriffen.", "Extraktionsplattform gefährdet."],
        },
    },
}

SYSTEM = {
    "build_complete": ["Konstruktion abgeschlossen.", "Gebäude betriebsbereit."],
    "unit_ready": ["Einheit einsatzbereit.", "Produktion abgeschlossen."],
    "base_attack": ["Basis unter Beschuss.", "Verteidigungsanlage angegriffen."],
    "energy_critical": ["Energieversorgung kritisch.", "Energiereserven erschöpfen sich."],
    "mission": ["Missionsziel aktualisiert.", "Primärziel erfüllt.", "Mission erfolgreich.", "Mission gescheitert."],
    "enemy_contact": ["Feindkontakt.", "Unbekannte Einheiten entdeckt."],
    "solar_low": ["Solaritvorrat niedrig.", "Solaritreserven werden knapp."],
    "refinery_active": ["Solarit-Verarbeitung aktiv."],
    "energy_stable": ["Energieversorgung stabil."],
    "structure_lost": ["Struktur verloren.", "Gebäude ausgefallen."],
    "harvester_danger": ["Sammler angegriffen.", "Sammler benötigt Unterstützung."],
}

PRIORITY = {
    "base_attack": 1, "harvest_danger": 1, "critical": 1, "energy_critical": 1,
    "mission": 1, "build_complete": 2, "unit_ready": 2, "success": 2,
    "damage": 2, "select": 3, "move": 3, "attack": 3,
}
UNIT_COOLDOWN = {"select": 8, "move": 5, "attack": 5, "damage": 12, "critical": 20}
EVENT_COOLDOWN = {"select": 2, "move": 3, "attack": 3, "damage": 8, "critical": 14}

def build_lines(faction_id, event_name, texts):
    return [{
        "id": f"voice_{faction_id}_{event_name}_{i:02}",
        "event": event_name,
        "text": text,
        "asset": "",
        "asset_state": "recording_required",
        "priority": PRIORITY.get(event_name, 3),
        "unit_cooldown": UNIT_COOLDOWN.get(event_name, 7),
        "event_cooldown": EVENT_COOLDOWN.get(event_name, 6),
    } for i, text in enumerate(texts, 1)]

catalog = {
    "schema_version": 1,
    "recordings_status": "not_recorded",
    "audio_format": "mono OGG Vorbis",
    "factions": {},
    "system": {},
}
for faction_id, faction in FACTIONS.items():
    catalog["factions"][faction_id] = {
        "display_name": faction["name"],
        "voice_identity": {"forge": "ruhig, professionell, robust", "drift": "direkt, rau, pragmatisch", "lumen": "kühl, analytisch, technologisch"}[faction_id],
        "lines": {event: build_lines(faction_id, event, texts) for event, texts in faction["lines"].items()},
    }
for event, texts in SYSTEM.items():
    catalog["system"][event] = [{
        "id": f"voice_neutral_{event}_{i:02}", "event": event, "text": text,
        "asset": "", "asset_state": "recording_required",
        "priority": PRIORITY.get(event, 2), "unit_cooldown": 0,
        "event_cooldown": EVENT_COOLDOWN.get(event, 8),
    } for i, text in enumerate(texts, 1)]

path = ROOT / "assets/audio/voice/voice_catalog.json"
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Wrote {sum(len(lines) for faction in catalog['factions'].values() for lines in faction['lines'].values())} faction lines and {sum(map(len, catalog['system'].values()))} system lines to {path}")
