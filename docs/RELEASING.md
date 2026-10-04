# Windows-Releases

Ein Release wird durch einen Tag der Form `vMAJOR.MINOR` gestartet. Die Tag-Version muss `current_version` in `data/update_history.json` entsprechen. GitHub Actions prüft zuerst die Tests, exportiert dann das Spiel mit der festgelegten Godot-Version, erstellt portable ZIP-Dateien sowie einen per-user Installer und hängt diese samt SHA-256-Manifest an eine GitHub Release an.

Für die erste Verbindung:

1. Das Projekt in das ASHLINE-Repository unter `DieListe01` übertragen.
2. In GitHub unter **Settings → Actions → General → Workflow permissions** das Erstellen von Releases durch den `GITHUB_TOKEN` erlauben (Workflow fordert `contents: write` an).
3. Den Workflow auf dem Standardbranch verfügbar machen und einen Tag wie `v0.35` pushen, sofern die Versionsdatei ebenfalls `0.35` nennt.

Der Release-Workflow lädt Godot 4.7.2 und dessen offiziellen Windows-Export-Template reproduzierbar für den Build-Runner. Die Godot-Engine und die Exportvorlage werden nicht ins Quell-Repository eingecheckt.

Installer und Spielstände liegen getrennt: Der Installer verwendet `%LOCALAPPDATA%\Programs\ASHLINE`; Godot legt Spielstände, Bestenliste und Einstellungen im Benutzerprofil ab. Der Inno-Setup-Installer ist pro Benutzer ausgelegt und verlangt für Installation und Updates keine Administratorrechte.
