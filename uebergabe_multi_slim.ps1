param(
    [ValidateSet("", "Code", "Standard", "Audio", "Art", "FPS", "Full")]
    [string]$Mode = "",

    [int]$TestOutputDays = 3,

    [int]$MaxStandardMB = 600,

    [switch]$AllowLargeStandard,

    [switch]$NoExplorer
)

# ============================================================
# SOLARIT: RANDSEKTOR 07 - flexibler Entwicklungs-Handoff
# Schlanke Version fuer ChatGPT-/Codex-Analyse
# ============================================================
#
# WICHTIGE AENDERUNGEN GEGENUEBER DER ALTEN VERSION:
#
# STANDARD
#   - Runtime-Audio nur als OGG + kleine Metadaten/Lizenzen
#   - keine WAV/FLAC/MP3/OPUS/M4A-Master/Kandidaten
#   - test-output nur per Whitelist, standardmaessig letzte 3 Tage
#   - grosse Tool-/TTS-/Piper-/Python-Verzeichnisse in test-output
#     werden ausgeschlossen
#   - keine alten EXE/ZIP/Runtime-Kopien aus test-output
#   - Vorpruefung mit groessten enthaltenen/ausgeschlossenen Dateien
#   - Schutz gegen versehentlich riesige Standard-Pakete
#
# AUDIO
#   - kompletter Audio-Fokus inkl. WAV/FLAC/MP3/OPUS/M4A
#   - Code/Tests/Doku werden weiter mitgeliefert
#
# ART
#   - Grafik/3D inkl. Blender-Quellen, ohne Audio
#
# FULL
#   - grosser Entwicklungs-Handoff, soweit nicht generell ausgeschlossen
#
# Immer ausgeschlossen:
#   .git, .godot, .local, build, handoff, export_templates,
#   GodotSharp, node_modules, virtuelle Umgebungen,
#   fertige EXE/MSI/PDB, Archive und temporaere Caches.
# ============================================================

$ErrorActionPreference = "Stop"

$ProjectRoot = "I:\Projekte\Spiele\Dune2"

# ------------------------------------------------------------
# Modus interaktiv auswaehlen, falls nicht per -Mode gesetzt
# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($Mode)) {

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " SOLARIT: RANDSEKTOR 07 - Handoff-Modus waehlen" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1  CODE" -ForegroundColor White
    Write-Host "     Klein: Code, Szenen, Tests, Doku, Daten, Skripte" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  2  STANDARD  (empfohlen / schlank)" -ForegroundColor Green
    Write-Host "     Code + Runtime-Assets + OGG-Audio + GLB/GLTF + Texturen +" -ForegroundColor DarkGray
    Write-Host "     kleine aktuelle Test-/Benchmark-Ergebnisse; ohne .blend/WAV-Master" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  3  AUDIO" -ForegroundColor Yellow
    Write-Host "     Musik, SFX, Voice inkl. Audio-Master/Kandidaten + Audio-Logik" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  4  ART / 3D" -ForegroundColor Magenta
    Write-Host "     Grafik, Texturen, GLB/GLTF UND Blender-Quellen; ohne Audio" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  5  FPS / PERFORMANCE" -ForegroundColor Cyan
    Write-Host "     Renderer, Simulation, Fahrzeug-/Gebaeudemodelle und aktuelle FPS-Messdaten" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  6  FULL" -ForegroundColor Red
    Write-Host "     Grosser Entwicklungs-Handoff inkl. Audio, 3D-Quellen und Testdaten" -ForegroundColor DarkGray
    Write-Host ""

    $Selection = Read-Host "Auswahl [1-6]"

    switch ($Selection) {
        "1" { $Mode = "Code" }
        "2" { $Mode = "Standard" }
        "3" { $Mode = "Audio" }
        "4" { $Mode = "Art" }
        "5" { $Mode = "FPS" }
        "6" { $Mode = "Full" }
        default { throw "Ungueltige Auswahl: $Selection" }
    }
}

$Timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$OutputDir = Join-Path $ProjectRoot "handoff"
$ZipFile = Join-Path $OutputDir "SOLARIT-RANDSEKTOR-07-Handoff-$Mode-$Timestamp.zip"
$TempRoot = Join-Path $env:TEMP "SOLARIT-RANDSEKTOR-07-Handoff-$Mode-$Timestamp"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SOLARIT: RANDSEKTOR 07 - $Mode Handoff" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectRoot)) {
    throw "Projektordner nicht gefunden: $ProjectRoot"
}

if (Test-Path $TempRoot) {
    Remove-Item $TempRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# ============================================================
# GRUNDSAETZLICHE AUSSCHLUESSE
# ============================================================

$AlwaysExcludedDirectories = @(
    ".git",
    ".godot",
    ".local",
    "build",
    "handoff",
    "export_templates",
    "GodotSharp",
    "__pycache__",
    ".venv",
    "venv",
    "node_modules"
)

$AlwaysExcludedExtensions = @(
    ".exe",
    ".msi",
    ".pdb",
    ".tmp",
    ".cache",
    ".zip",
    ".7z",
    ".rar",
    ".iso",
    ".dmp"
)

$AlwaysExcludedFileNames = @(
    "Thumbs.db",
    ".DS_Store"
)

$AllAudioExtensions = @(
    ".wav",
    ".ogg",
    ".mp3",
    ".flac",
    ".opus",
    ".m4a"
)

$RuntimeAudioExtensions = @(
    ".ogg"
)

$AudioMetadataExtensions = @(
    ".json",
    ".txt",
    ".md",
    ".cfg",
    ".tres",
    ".res",
    ".import"
)

$ModelExtensions = @(
    ".glb",
    ".gltf",
    ".blend",
    ".blend1",
    ".blend2",
    ".fbx",
    ".obj"
)

$BlendExtensions = @(
    ".blend",
    ".blend1",
    ".blend2"
)

$TestOutputAllowedExtensions = @(
    ".csv",
    ".json",
    ".txt",
    ".log",
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".md",
    ".xml",
    ".html"
)

$TestOutputImageExtensions = @(
    ".png",
    ".jpg",
    ".jpeg",
    ".webp"
)

# Maximalgroesse einzelner Test-Screenshots im normalen Handoff.
$MaxTestImageBytes = 10MB

# In diesen test-output-Bereichen liegen Werkzeuge, Modelle, Runtimes,
# Kopien oder grosse technische Zwischenartefakte. Sie gehoeren nicht
# in Code/Standard/Art-Handovers.
$HeavyTestOutputPathPatterns = @(
    "test-output\audio-tools\*",
    "test-output\audio-voice-review\*",
    "test-output\audio-review\*",
    "test-output\fresh-project\*",
    "test-output\ab-user-data\*",
    "test-output\*\piper-runtime\*",
    "test-output\*\site\*",
    "test-output\*\sources\*",
    "test-output\*\__pycache__\*",
    "test-output\*\AppData\*",
    "test-output\*\appdata\*",
    "test-output\ci\artifact-*\*",
    "test-output\*release-verify*\*"
)

# ============================================================
# MODUS-DEFINITION
# ============================================================

$ModeInfo = @{
    "Code" = @{
        Description = "Code-/Logik-/Testanalyse ohne grosse Runtime-Assets"
        AudioPolicy = "None"
        IncludeGraphics = $false
        IncludeBlend = $false
        IncludeTestOutput = $true
        FullTestOutput = $false
        IncludeInfrastructure = $true
    }

    "Standard" = @{
        Description = "Schlanker allgemeiner Handoff mit Runtime-Assets und Runtime-OGG"
        AudioPolicy = "Runtime"
        IncludeGraphics = $true
        IncludeBlend = $false
        IncludeTestOutput = $true
        FullTestOutput = $false
        IncludeInfrastructure = $true
    }

    "Audio" = @{
        Description = "Musik-/SFX-/Voice-Bewertung inklusive Audio-Master/Kandidaten und Audio-Logik"
        AudioPolicy = "All"
        IncludeGraphics = $false
        IncludeBlend = $false
        IncludeTestOutput = $false
        FullTestOutput = $false
        IncludeInfrastructure = $false
    }

    "Art" = @{
        Description = "Grafik-/3D-Bewertung inkl. Blender-Quellen, ohne Audio"
        AudioPolicy = "None"
        IncludeGraphics = $true
        IncludeBlend = $true
        IncludeTestOutput = $true
        FullTestOutput = $false
        IncludeInfrastructure = $true
    }

    "FPS" = @{
        Description = "Gezieltes FPS-Paket: Render-/Simulationscode, relevante Modelle, Benchmarks und aktuelle Messdaten"
        AudioPolicy = "None"
        IncludeGraphics = $true
        IncludeBlend = $false
        IncludeTestOutput = $true
        FullTestOutput = $false
        IncludeInfrastructure = $false
    }

    "Full" = @{
        Description = "Grosser Entwicklungs-Handoff inkl. Audio, Blender und Testausgaben"
        AudioPolicy = "All"
        IncludeGraphics = $true
        IncludeBlend = $true
        IncludeTestOutput = $true
        FullTestOutput = $true
        IncludeInfrastructure = $true
    }
}

$Settings = $ModeInfo[$Mode]

# ============================================================
# HILFSFUNKTIONEN
# ============================================================

function Get-RelativeProjectPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FullPath
    )

    return $FullPath.Substring($ProjectRoot.Length).TrimStart("\", "/")
}

function Get-NormalizedRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    return ($RelativePath -replace "/", "\")
}

function Test-PathContainsExcludedDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $Parts = $RelativePath -split "[\\/]"

    foreach ($Part in $Parts) {
        if ($AlwaysExcludedDirectories -contains $Part) {
            return $true
        }
    }

    return $false
}

function Test-IsAudioTreePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $Normalized = Get-NormalizedRelativePath $RelativePath
    return $Normalized -like "assets\audio\*"
}

function Test-ShouldIncludeAudioFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $Relative = Get-RelativeProjectPath $File.FullName
    $Extension = $File.Extension.ToLowerInvariant()

    if (-not (Test-IsAudioTreePath $Relative)) {
        return $false
    }

    switch ($Settings.AudioPolicy) {
        "None" {
            return $false
        }

        "Runtime" {
            # STANDARD: nur Runtime-Audio + kleine Metadaten/Lizenzen.
            if ($RuntimeAudioExtensions -contains $Extension) {
                return $true
            }

            if ($AudioMetadataExtensions -contains $Extension) {
                return $true
            }

            return $false
        }

        "All" {
            # AUDIO/FULL: alle Audioformate und Metadaten im Audio-Baum.
            return $true
        }
    }

    return $false
}

function Test-IsGraphicsAsset {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $Relative = Get-RelativeProjectPath $File.FullName
    $Normalized = Get-NormalizedRelativePath $Relative

    if ($Normalized -notlike "assets\*") {
        return $false
    }

    if (Test-IsAudioTreePath $Relative) {
        return $false
    }

    return $true
}

function Test-IsBlendFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    return $BlendExtensions -contains $File.Extension.ToLowerInvariant()
}

function Test-IsTestOutputFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $Relative = Get-NormalizedRelativePath (Get-RelativeProjectPath $File.FullName)
    return $Relative -like "test-output\*"
}

function Test-IsHeavyTestOutputPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $Normalized = Get-NormalizedRelativePath $RelativePath

    foreach ($Pattern in $HeavyTestOutputPathPatterns) {
        if ($Normalized -like $Pattern) {
            return $true
        }
    }

    return $false
}

function Test-IsInfrastructurePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $Normalized = Get-NormalizedRelativePath $RelativePath

    return (
        $Normalized -like ".github\*" -or
        $Normalized -like "server\*" -or
        $Normalized -like "installer\*"
    )
}

function Test-IsCommonProjectPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $CommonRoots = @(
        "scripts",
        "scenes",
        "tests",
        "docs",
        "data",
        "tools",
        "feature_profiles",
        "script_templates"
    )

    $FirstPart = ($RelativePath -split "[\\/]")[0]
    return $CommonRoots -contains $FirstPart
}

function Test-IsUsefulRootFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $Relative = Get-RelativeProjectPath $File.FullName

    if ($Relative -match "[\\/]") {
        return $false
    }

    return $true
}

function Test-ShouldIncludeProjectFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $Relative = Get-RelativeProjectPath $File.FullName
    $Normalized = Get-NormalizedRelativePath $Relative
    $Extension = $File.Extension.ToLowerInvariant()

    if (Test-PathContainsExcludedDirectory $Relative) {
        return $false
    }

    if ($AlwaysExcludedExtensions -contains $Extension) {
        return $false
    }

    if ($AlwaysExcludedFileNames -contains $File.Name) {
        return $false
    }

    # test-output wird separat und strenger behandelt.
    if (Test-IsTestOutputFile $File) {
        return $false
    }

    # Projektstamm: project.godot, README, Build/Test-Skripte usw.
    if (Test-IsUsefulRootFile $File) {
        return $true
    }

    # Gemeinsamer Quell-/Dokumentations-/Tool-Bestand.
    if (Test-IsCommonProjectPath $Relative) {
        return $true
    }

    # Infrastruktur.
    if (Test-IsInfrastructurePath $Relative) {
        return [bool]$Settings.IncludeInfrastructure
    }

    # Audio separat behandeln.
    if (Test-IsAudioTreePath $Relative) {
        return (Test-ShouldIncludeAudioFile $File)
    }

    # Sonstige Assets = Grafik/Modelle/Runtime-Assets.
    if ($Normalized -like "assets\*") {

        if (-not [bool]$Settings.IncludeGraphics) {
            return $false
        }

        if ((Test-IsBlendFile $File) -and -not [bool]$Settings.IncludeBlend) {
            return $false
        }

        return $true
    }

    # FULL nimmt zusaetzlich weitere nicht ausgeschlossene Projektdateien mit.
    if ($Mode -eq "Full") {
        return $true
    }

    return $false
}

function Test-ShouldIncludeFpsFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $Relative = Get-NormalizedRelativePath (Get-RelativeProjectPath $File.FullName)
    $Name = $File.Name.ToLowerInvariant()

    if ($AlwaysExcludedExtensions -contains $File.Extension.ToLowerInvariant()) { return $false }
    if ($AlwaysExcludedFileNames -contains $File.Name) { return $false }

    # Projekt-/Render-Konfiguration und die von der Messszene verwendeten Daten.
    if ($Relative -in @("project.godot", "scenes\main.tscn", "data\catalog.json", "data\veyra.json")) { return $true }

    # Kernpfad: Spielschleife, WorldRenderer, Simulation, Cache, Modelle, VFX und Terrain.
    $FpsScripts = @(
        "main", "world_renderer", "simulation", "grid", "combat_effects",
        "vehicle_cache_painter", "building_cache_painter", "production_preview_cache",
        "model_asset_library", "lowpoly_model_factory", "industrial_art", "catalog",
        "terrain_detail_painter", "battlefield_polish", "combat_vfx",
        "performance", "performance_monitor", "render_performance"
    )
    if ($Relative -like "scripts\*") {
        if ($Name.EndsWith(".gd.uid")) {
            $ScriptName = $Name.Substring(0, $Name.Length - 7)
        }
        else {
            $ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($Name)
        }
        if ($FpsScripts -contains $ScriptName) { return $true }
    }

    # Reproduzierbare Gefechts-/Performance-Checks und ihre direkten Hilfsskripte.
    if ($Relative -like "tests\*") {
        if ($Name -match "(moving_battle_benchmark|fps|performance|combat_perf|warm_bottleneck)") { return $true }
    }

    # Die für die Darstellung verwendeten GLB-Assets inklusive Godot-Importmetadaten.
    if ($Relative -like "assets\models\vehicles\*" -or $Relative -like "assets\models\buildings\*") {
        return ($File.Extension.ToLowerInvariant() -in @(".glb", ".gltf", ".import"))
    }

    # Nur FPS-bezogene Diagnoseausgaben der letzten N Tage; keine beliebigen Testartefakte.
    if ($Relative -like "test-output\*") {
        if ($File.LastWriteTime -lt $Cutoff) { return $false }
        if ($Name -notmatch "^(fps_10buildings_50vehicles|moving_battle_benchmark|warm_bottleneck|combat_perf)") { return $false }
        return ($File.Extension.ToLowerInvariant() -in @(".csv", ".json", ".txt", ".log", ".md", ".gd"))
    }

    return $false
}

function Test-ShouldIncludeTestOutputFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [datetime]$Cutoff
    )

    $Relative = Get-RelativeProjectPath $File.FullName
    $Extension = $File.Extension.ToLowerInvariant()

    if (Test-PathContainsExcludedDirectory $Relative) {
        return $false
    }

    if ($AlwaysExcludedExtensions -contains $Extension) {
        return $false
    }

    if ($AlwaysExcludedFileNames -contains $File.Name) {
        return $false
    }

    if (-not [bool]$Settings.FullTestOutput) {

        if (Test-IsHeavyTestOutputPath $Relative) {
            return $false
        }

        if ($TestOutputAllowedExtensions -notcontains $Extension) {
            return $false
        }

        if ($File.LastWriteTime -lt $Cutoff) {
            return $false
        }

        if (($TestOutputImageExtensions -contains $Extension) -and
            $File.Length -gt $MaxTestImageBytes) {
            return $false
        }

        return $true
    }

    # FULL: weiterhin keine generell ausgeschlossenen Binaer-/Archivformate,
    # sonst test-output komplett zulassen.
    return $true
}

function Copy-ProjectFileAbsolute {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    $Relative = Get-RelativeProjectPath $Source
    $Destination = Join-Path $TempRoot $Relative
    $Parent = Split-Path $Destination -Parent

    if (-not (Test-Path $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Format-Size {
    param(
        [Parameter(Mandatory = $true)]
        [int64]$Bytes
    )

    if ($Bytes -ge 1GB) {
        return ("{0:N2} GB" -f ($Bytes / 1GB))
    }

    if ($Bytes -ge 1MB) {
        return ("{0:N2} MB" -f ($Bytes / 1MB))
    }

    if ($Bytes -ge 1KB) {
        return ("{0:N2} KB" -f ($Bytes / 1KB))
    }

    return "$Bytes Bytes"
}

# ============================================================
# 1. PROJEKTDATEIEN EINMAL SCANNEN / VORPRUEFUNG
# ============================================================

Write-Host "[MODE  ] $Mode" -ForegroundColor Green
Write-Host "[INFO  ] $($Settings.Description)" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "Scanne Projektdateien ..." -ForegroundColor Yellow

$AllProjectFiles = Get-ChildItem -Path $ProjectRoot -File -Recurse -Force -ErrorAction SilentlyContinue
$Cutoff = (Get-Date).AddDays(-$TestOutputDays)

$SelectedFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]
$ExcludedFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]

foreach ($File in $AllProjectFiles) {

    $Include = $false

    if ($Mode -eq "FPS") {
        $Include = Test-ShouldIncludeFpsFile -File $File
    }
    elseif ((Test-IsTestOutputFile $File) -and [bool]$Settings.IncludeTestOutput) {
        $Include = Test-ShouldIncludeTestOutputFile -File $File -Cutoff $Cutoff
    }
    elseif (Test-IsTestOutputFile $File) {
        $Include = $false
    }
    else {
        $Include = Test-ShouldIncludeProjectFile $File
    }

    if ($Include) {
        $SelectedFiles.Add($File)
    }
    else {
        $ExcludedFiles.Add($File)
    }
}

$PreflightBytes = [int64](($SelectedFiles | Measure-Object -Property Length -Sum).Sum)
$PreflightMB = [math]::Round($PreflightBytes / 1MB, 2)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " VORPRUEFUNG" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ("Ausgewaehlte Dateien : {0}" -f $SelectedFiles.Count) -ForegroundColor White
Write-Host ("Unkomprimiert        : {0}" -f (Format-Size $PreflightBytes)) -ForegroundColor White
Write-Host ("Test-output-Zeitraum : letzte {0} Tage" -f $TestOutputDays) -ForegroundColor White
Write-Host ""
Write-Host "Groesste enthaltene Dateien:" -ForegroundColor Yellow

$SelectedFiles |
    Sort-Object Length -Descending |
    Select-Object -First 20 |
    ForEach-Object {
        $Relative = Get-RelativeProjectPath $_.FullName
        Write-Host ("  {0,10}  {1}" -f (Format-Size $_.Length), $Relative) -ForegroundColor DarkGray
    }

Write-Host ""
Write-Host "Groesste ausgeschlossene Dateien:" -ForegroundColor Yellow

$ExcludedFiles |
    Sort-Object Length -Descending |
    Select-Object -First 20 |
    ForEach-Object {
        $Relative = Get-RelativeProjectPath $_.FullName
        Write-Host ("  {0,10}  {1}" -f (Format-Size $_.Length), $Relative) -ForegroundColor DarkGray
    }

if (($Mode -eq "Standard") -and ($PreflightMB -gt $MaxStandardMB) -and -not $AllowLargeStandard) {
    Write-Host ""
    Write-Warning "STANDARD waere mit $PreflightMB MB groesser als das Limit von $MaxStandardMB MB."
    Write-Warning "Es wurde absichtlich NOCH KEIN ZIP erzeugt."
    Write-Warning "Falls die Groesse wirklich gewollt ist: -AllowLargeStandard verwenden."
    throw "Standard-Handoff zu gross: $PreflightMB MB"
}

# ============================================================
# 2. AUSGEWAEHLTE DATEIEN KOPIEREN
# ============================================================

Write-Host ""
Write-Host "Sammle ausgewaehlte Dateien ..." -ForegroundColor Yellow

$CopiedFiles = 0
$CopiedBytes = [int64]0

foreach ($File in $SelectedFiles) {
    Copy-ProjectFileAbsolute $File.FullName
    $CopiedFiles++
    $CopiedBytes += $File.Length
}

if ($Mode -eq "FPS") {
    $FpsReadme = Join-Path $TempRoot "FPS_PACKAGE_README.md"
    @"
# SOLARIT FPS-Diagnosepaket

Erzeugt am: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Git-Commit: $((git -C $ProjectRoot rev-parse --short HEAD 2>$null) -join "")

## Paketstruktur

- `scripts/`: Spielschleife, WorldRenderer, Simulation, Cache-, VFX- und Terrain-Code
- tests/: bewegter Gefechtsbenchmark und Performanceprüfungen
- assets/models/vehicles/ und assets/models/buildings/: verwendete GLB-Modelle plus Importmetadaten
- test-output/: aktuelle CSV-Frameverläufe, Cache-Key-Protokolle, Logs und Test-Harnesses
- `_FILELIST.txt`, `_HANDOFF_INFO.txt`, `_GIT_*.txt`: Paketinhalt und Git-Kontext

## Regelmäßig erzeugen

Im Projektordner ausführen:

powershell -ExecutionPolicy Bypass -File .\uebergabe_multi_slim.ps1 -Mode FPS

Die ZIP landet in handoff/. Messdaten aus test-output/ werden auf die letzten $TestOutputDays Tage begrenzt.
Es werden keine Builds, ausführbaren Dateien, Blender-Quelldateien oder Audioassets eingepackt.
"@ | Set-Content -LiteralPath $FpsReadme -Encoding UTF8
}

# ============================================================
# 3. INVENTARE DES GESAMTEN PROJEKTS
# ============================================================

Write-Host "[LISTE ] Audio-/3D-/Grossdatei-Inventar" -ForegroundColor Green

$AudioInventory = Join-Path $TempRoot "_AUDIO_FILES.txt"

Get-ChildItem -Path $ProjectRoot -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object {
        -not (Test-PathContainsExcludedDirectory (Get-RelativeProjectPath $_.FullName)) -and
        $AllAudioExtensions -contains $_.Extension.ToLowerInvariant()
    } |
    Sort-Object FullName |
    ForEach-Object {
        $Relative = Get-RelativeProjectPath $_.FullName
        "{0}`t{1}`t{2}" -f $Relative, (Format-Size $_.Length), $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    } |
    Set-Content -Path $AudioInventory -Encoding UTF8

$ModelInventory = Join-Path $TempRoot "_3D_ASSETS.txt"

Get-ChildItem -Path $ProjectRoot -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object {
        -not (Test-PathContainsExcludedDirectory (Get-RelativeProjectPath $_.FullName)) -and
        $ModelExtensions -contains $_.Extension.ToLowerInvariant()
    } |
    Sort-Object FullName |
    ForEach-Object {
        $Relative = Get-RelativeProjectPath $_.FullName
        "{0}`t{1}`t{2}" -f $Relative, (Format-Size $_.Length), $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    } |
    Set-Content -Path $ModelInventory -Encoding UTF8

$LargestFilesInventory = Join-Path $TempRoot "_LARGEST_PROJECT_FILES.txt"

Get-ChildItem -Path $ProjectRoot -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object {
        -not (Test-PathContainsExcludedDirectory (Get-RelativeProjectPath $_.FullName))
    } |
    Sort-Object Length -Descending |
    Select-Object -First 100 |
    ForEach-Object {
        $Relative = Get-RelativeProjectPath $_.FullName
        "{0}`t{1}" -f (Format-Size $_.Length), $Relative
    } |
    Set-Content -Path $LargestFilesInventory -Encoding UTF8

$SizeReport = Join-Path $TempRoot "_HANDOFF_SIZE_REPORT.txt"

$SizeReportLines = New-Object System.Collections.Generic.List[string]
$SizeReportLines.Add("SOLARIT: RANDSEKTOR 07 - Handoff Groessenreport")
$SizeReportLines.Add("================================================")
$SizeReportLines.Add("")
$SizeReportLines.Add("Modus: $Mode")
$SizeReportLines.Add("Ausgewaehlte Dateien: $($SelectedFiles.Count)")
$SizeReportLines.Add("Unkomprimiert: $(Format-Size $PreflightBytes)")
$SizeReportLines.Add("")
$SizeReportLines.Add("30 groesste enthaltene Dateien:")

$SelectedFiles |
    Sort-Object Length -Descending |
    Select-Object -First 30 |
    ForEach-Object {
        $SizeReportLines.Add(("{0}`t{1}" -f (Format-Size $_.Length), (Get-RelativeProjectPath $_.FullName)))
    }

$SizeReportLines.Add("")
$SizeReportLines.Add("30 groesste ausgeschlossene Dateien:")

$ExcludedFiles |
    Sort-Object Length -Descending |
    Select-Object -First 30 |
    ForEach-Object {
        $SizeReportLines.Add(("{0}`t{1}" -f (Format-Size $_.Length), (Get-RelativeProjectPath $_.FullName)))
    }

$SizeReportLines | Set-Content -Path $SizeReport -Encoding UTF8

# ============================================================
# 4. GIT-INFORMATIONEN
# ============================================================

$GitExe = Get-Command git -ErrorAction SilentlyContinue

if ($null -ne $GitExe) {

    Write-Host "[GIT   ] Status / Branch / Commit / Log / Diff" -ForegroundColor Green

    Push-Location $ProjectRoot

    try {
        git status --short |
            Out-File (Join-Path $TempRoot "_GIT_STATUS.txt") -Encoding UTF8

        git branch --show-current |
            Out-File (Join-Path $TempRoot "_GIT_BRANCH.txt") -Encoding UTF8

        git rev-parse HEAD |
            Out-File (Join-Path $TempRoot "_GIT_COMMIT.txt") -Encoding UTF8

        git log -n 30 --oneline --decorate |
            Out-File (Join-Path $TempRoot "_GIT_LOG.txt") -Encoding UTF8

        git diff --stat |
            Out-File (Join-Path $TempRoot "_GIT_DIFF_STAT.txt") -Encoding UTF8

        git diff |
            Out-File (Join-Path $TempRoot "_GIT_DIFF.patch") -Encoding UTF8
    }
    catch {
        Write-Warning "Git-Informationen konnten nicht vollstaendig erzeugt werden: $($_.Exception.Message)"
    }
    finally {
        Pop-Location
    }
}

# ============================================================
# 5. HANDOFF-INFO
# ============================================================

$ManifestFile = Join-Path $TempRoot "_HANDOFF_INFO.txt"

$TestOutputDescription = "nicht enthalten"
if ([bool]$Settings.IncludeTestOutput) {
    if ([bool]$Settings.FullTestOutput) {
        $TestOutputDescription = "vollstaendig, abgesehen von generellen Binary-/Archiv-Ausschluessen"
    }
    else {
        $TestOutputDescription = "Whitelist, letzte $TestOutputDays Tage; schwere Tool-/Runtime-Verzeichnisse ausgeschlossen"
    }
}

$AudioDescription = switch ($Settings.AudioPolicy) {
    "None" { "nicht enthalten; Inventar vorhanden" }
    "Runtime" { "Runtime-OGG + Audio-Metadaten/Lizenzen" }
    "All" { "kompletter Audio-Baum soweit nicht generell ausgeschlossen" }
    default { "unbekannt" }
}

$Manifest = @"
SOLARIT: RANDSEKTOR 07 - Entwicklungs-Handoff
=============================================

Erstellt:
$(Get-Date -Format "dd.MM.yyyy HH:mm:ss")

Projektquelle:
$ProjectRoot

MODUS:
$Mode

Beschreibung:
$($Settings.Description)

Unkomprimierte Vorpruefung:
$(Format-Size $PreflightBytes)

Test-output:
$TestOutputDescription

Audio-Dateien:
$AudioDescription

Grafik-/Runtime-Assets:
$(if ([bool]$Settings.IncludeGraphics) { "enthalten" } else { "nicht enthalten; Inventar vorhanden" })

Blender-Quellen:
$(if ([bool]$Settings.IncludeBlend) { "enthalten" } else { "nicht enthalten; Inventar vorhanden" })

Infrastruktur (.github/server/installer):
$(if ([bool]$Settings.IncludeInfrastructure) { "enthalten" } else { "nicht enthalten" })

STANDARD SPEZIELL AUSGESCHLOSSEN:
- WAV/FLAC/MP3/OPUS/M4A-Master und -Kandidaten
- test-output/audio-tools
- test-output/audio-voice-review
- test-output/audio-review
- test-output/fresh-project
- test-output/ab-user-data
- Piper-Runtimes / ONNX-Testmodelle / Python site-Verzeichnisse in test-output
- alte EXE/ZIP/Buildartefakte
- Testbilder > 10 MB

IMMER ENTHALTEN:
- Quellcode
- Szenen
- Tests
- Dokumentation
- Daten
- Entwicklungs-Tools
- wichtige Root-Dateien
- Git-Status / Branch / Commit / Log / Diff
- _AUDIO_FILES.txt
- _3D_ASSETS.txt
- _LARGEST_PROJECT_FILES.txt
- _HANDOFF_SIZE_REPORT.txt
- _FILELIST.txt

BEWUSST NICHT ENTHALTEN:
- .git
- .godot
- .local
- build
- handoff
- export_templates
- GodotSharp
- Godot EXE
- fertige Windows EXE/MSI/PDB
- alte ZIP/7z/RAR-Pakete
- Crash-Dumps
- temporaere Caches

Hinweis:
Dies ist ein Entwicklungs-/Analyse-Handoff und kein Backup.
"@

Set-Content -Path $ManifestFile -Value $Manifest -Encoding UTF8

# ============================================================
# 6. DATEILISTE DES HANDOFFS
# ============================================================

$FileList = Join-Path $TempRoot "_FILELIST.txt"

Get-ChildItem -Path $TempRoot -File -Recurse |
    Sort-Object FullName |
    ForEach-Object {
        $Relative = $_.FullName.Substring($TempRoot.Length + 1)
        "{0}`t{1}" -f $Relative, $_.Length
    } |
    Set-Content -Path $FileList -Encoding UTF8

# ============================================================
# 7. FINALE GROESSENPRUEFUNG
# ============================================================

$StageBytes = [int64]((Get-ChildItem -Path $TempRoot -File -Recurse | Measure-Object -Property Length -Sum).Sum)
$StageMB = [math]::Round($StageBytes / 1MB, 2)

Write-Host ""
Write-Host "Dateien im Handoff: $CopiedFiles" -ForegroundColor White
Write-Host "Unkomprimierte Handoff-Groesse: $StageMB MB" -ForegroundColor White

if (($Mode -eq "Standard") -and ($StageMB -gt $MaxStandardMB) -and -not $AllowLargeStandard) {
    Write-Warning "STANDARD ist nach dem Staging mit $StageMB MB groesser als das Limit von $MaxStandardMB MB."
    Write-Warning "Der Temp-Ordner bleibt fuer die Analyse bestehen: $TempRoot"
    throw "Standard-Handoff nach Staging zu gross: $StageMB MB"
}

if ($StageMB -gt 1500) {
    Write-Warning "Das Paket ist groesser als 1,5 GB. AUDIO/ART/FULL koennen absichtlich gross werden."
}

# ============================================================
# 8. ZIP ERZEUGEN
# ============================================================

Write-Host ""
Write-Host "Erzeuge ZIP ..." -ForegroundColor Yellow

if (Test-Path $ZipFile) {
    Remove-Item $ZipFile -Force
}

Compress-Archive `
    -Path (Join-Path $TempRoot "*") `
    -DestinationPath $ZipFile `
    -CompressionLevel Optimal `
    -Force

# ============================================================
# 9. TEMPORDNER ENTFERNEN
# ============================================================

Remove-Item -Path $TempRoot -Recurse -Force

# ============================================================
# 10. ERGEBNIS
# ============================================================

$ZipInfo = Get-Item $ZipFile
$SizeMB = [math]::Round($ZipInfo.Length / 1MB, 2)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " FERTIG" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Modus: $Mode" -ForegroundColor White
Write-Host "ZIP:" -ForegroundColor White
Write-Host $ZipFile -ForegroundColor Cyan
Write-Host ""
Write-Host "ZIP-Groesse: $SizeMB MB" -ForegroundColor White
Write-Host ""

if (-not $NoExplorer) {
    Start-Process explorer.exe -ArgumentList "/select,`"$ZipFile`""
}
