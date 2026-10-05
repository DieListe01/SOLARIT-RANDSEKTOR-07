# Windows-Releases

SOLARIT: RANDSEKTOR 07 verwendet zwei GitHub-Repositories:

- `DieListe01/SOLARIT-RANDSEKTOR-07` enthält den privaten Quellcode.
- `DieListe01/ASHLINE-Releases` ist öffentlich und enthält nur Installer-Releases, SHA-256-Dateien und Versionsmanifeste. Es wird kein Quellarchiv hochgeladen.

## Einmalige GitHub-Einrichtung

Erstelle ein fein abgestimmtes persönliches Zugriffstoken, das nur für `DieListe01/ASHLINE-Releases` gilt und dort **Contents: Read and write** erhält. Hinterlege es im privaten Quell-Repository unter **Settings → Secrets and variables → Actions → New repository secret** mit dem Namen `ASHLINE_RELEASE_TOKEN`. GitHub speichert das Token als Secret; der Workflow verwendet es ausschließlich, um das öffentliche Binär-Release anzulegen. Ein Token gehört niemals in den Quellcode.

## Eine Version veröffentlichen

Aktualisiere `current_version` und ergänze einen datierten Eintrag in `data/update_history.json`. Committe und pushe die Änderungen im privaten Quell-Repository, danach einen passenden Tag wie `vX.Y.Z`. GitHub Actions prüft die Versionsnummer, führt `Test-Solarit.ps1` aus, exportiert das Spiel mit Godot 4.7.2 und baut den benutzerbezogenen Inno-Setup-Installer. Anschließend veröffentlicht der Workflow Installer, SHA-256-Datei und Manifest in `DieListe01/ASHLINE-Releases`.

Das Spiel verwendet `DieListe01/ASHLINE-Releases` als Updatekanal. Es liest das aktuelle öffentliche Release, prüft Manifest und Installer-Prüfsumme und fragt vor dem Start des Installers ausdrücklich nach. Spielstände bleiben im Godot-Benutzerordner; der Installer schreibt nach `%LOCALAPPDATA%\Programs\SOLARIT-RANDSEKTOR-07`.

Der Workflow erstellt während des Builds zusätzlich ein portables Windows-ZIP zur internen Prüfung. Im öffentlichen Feed liegen ausschließlich der Installer und die Update-Prüfdateien.
