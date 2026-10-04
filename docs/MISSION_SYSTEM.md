# SOLARIT: RANDSEKTOR 07 – Missionssystem 0.20

Missionen liegen als JSON unter `data/`. Die aktuell spielbaren Einsätze sind `veyra.json`, `dry_vein.json` und `khepri_pass.json`.

## Unterstützte Zieltypen

- `destroy_target`: alle Gebäude des angegebenen Besitzers und Typs zerstören.
- `destroy_all`: alle passenden Einheiten/Gebäude des Besitzers zerstören; `kind` kann leer bleiben.
- `protect`: das angegebene eigene Gebäude muss erhalten bleiben. Verlust beendet den Einsatz mit Niederlage.
- `survive`: bis zur angegebenen Anzahl Sekunden durchhalten.
- `harvest_amount`: die angegebene Solarit-Menge muss tatsächlich an eigene Raffinerien geliefert werden.
- `build_structure`: eine Anzahl fertiggestellter Gebäude eines Typs betreiben.

Mehrere Ziele mit `"primary": true` werden gemeinsam ausgewertet. Sieg tritt erst ein, wenn alle Primärziele erfüllt sind. Ziele ohne `primary` sind optional bzw. Schutzziele und blockieren den Sieg nicht, außer `protect` schlägt fehl.

## Angriffswellen

Eine Mission kann `waves` enthalten. Jede Welle besitzt mindestens `time`, `spawn_cell` und `units`. `units` kann eine Liste oder ein Dictionary mit `easy`, `normal` und `hard` sein. Gespawnte Fahrzeuge sind normale Simulationseinheiten: Sie nutzen Wegfindung, Kampf, Sicht und Kollision wie alle anderen Fahrzeuge und werden nicht teleportiert.

Beispiel:

```json
{
  "time": 150,
  "spawn_cell": [32, 14],
  "units": {
    "easy": ["tank", "scout"],
    "normal": ["tank", "tank", "scout"],
    "hard": ["tank", "tank", "tank", "siege"]
  },
  "message": "WELLE 2 · Gepanzerter Vorstoß."
}
```

Der Wellenfortschritt wird gespeichert, damit eine bereits ausgelöste Welle nach Laden nicht erneut entsteht.

## Visuelle Kartendetails

Missionen können `ruins` und `craters` definieren. Diese Einträge werden nur in der Darstellung verwendet und verändern keine Simulation oder Wegfindung. Damit können Karten ohne zusätzliche Nodes als bereits umkämpfte Orte gestaltet werden.

## Aktuelle Einsätze

1. **Das Veyra-Becken** – Aufbau, Erkundung und Angriff auf den gegnerischen Baukern.
2. **Die trockene Ader** – Wirtschaft und Expansion: 8.000 Solarit liefern, zwei Raffinerien betreiben und die feindliche Raffinerie ausschalten.
3. **Engpass Khepri** – Verteidigung: 15 Minuten halten, mit sechs echten Angriffswellen und optionalem Solaritziel.
