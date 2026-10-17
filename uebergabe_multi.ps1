param(
    [ValidateSet("", "Code", "Standard", "Audio", "Art", "Full")]
    [string]$Mode = "",

    [int]$TestOutputDays = 14,

    [switch]$NoExplorer
)

# ============================================================
# SOLARIT: RANDSEKTOR 07 - flexibler Entwicklungs-Handoff
# ============================================================
#
# Modi:
#
# Code
#   Kleines Paket fuer Code-/Logik-/Testanalyse.
#   Keine grossen Laufzeit-Assets.
#
# Standard   <-- EMPFOHLEN fuer normale ChatGPT-Analyse
#   Code + Laufzeit-Assets + Audio + GLB/GLTF + Texturen +
#   aktuelle Testausgaben + CI/Server/Installer/Tools.
#   Keine .blend-Quelldateien.
#
# Audio
#   Fokus auf Musik, SFX, Voice und Audio-Logik.
#   Ideal fuer Musik-/Sound-/Sprachbewertung.
#
# Art
#   Fokus auf Grafik/3D. Enthält Runtime-Grafikassets UND
#   Blender-Quellen (.blend), aber keine Audio-Assets.
#
# Full
#   Vollstaendiger Entwicklungs-Handoff:
#   gesamter relevante Quellstand + alle Assets inkl. Audio
#   und Blender-Quellen + komplette test-output-Inhalte.
#
# Immer ausgeschlossen:
#   .git, .godot, .local, build, handoff, export_templates,
#   GodotSharp, node_modules, virtuelle Umgebungen,
#   fertige EXE/MSI, alte ZIP/7z/RAR-Pakete und temporaere Caches.
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
    Write-Host "  2  STANDARD  (empfohlen)" -ForegroundColor Green
    Write-Host "     Code + Runtime-Assets + Musik/SFX/Voice + GLB/GLTF +" -ForegroundColor DarkGray
    Write-Host "     aktuelle Tests/Benchmarks; ohne .blend-Quellen" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  3  AUDIO" -ForegroundColor Yellow
    Write-Host "     Musik, SFX, Voice + Audio-Logik/Tests" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  4  ART / 3D" -ForegroundColor Magenta
    Write-Host "     Grafik, Texturen, GLB/GLTF UND Blender-Quellen; ohne Audio" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  5  FULL" -ForegroundColor Red
    Write-Host "     Alles Relevante inkl. Audio, 3D-Quellen und test-output" -ForegroundColor DarkGray
    Write-Host ""

    $Selection = Read-Host "Auswahl [1-5]"

    switch ($Selection) {
        "1" { $Mode = "Code" }
        "2" { $Mode = "Standard" }
        "3" { $Mode = "Audio" }
        "4" { $Mode = "Art" }
        "5" { $Mode = "Full" }
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
    ".iso"
)

$AlwaysExcludedFileNames = @(
    "Thumbs.db",
    ".DS_Store"
)

$AudioExtensions = @(
    ".wav",
    ".ogg",
    ".mp3",
    ".flac",
    ".opus",
    ".m4a"
)

$ModelExtensions = @(
    ".glb",
    ".gltf",
    ".blend",
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

# ============================================================
# MODUS-DEFINITION
# ============================================================

$ModeInfo = @{
    "Code" = @{
        Description = "Code-/Logik-/Testanalyse ohne grosse Runtime-Assets"
        IncludeAudio = $false
        IncludeGraphics = $false
        IncludeBlend = $false
        IncludeTestOutput = $true
        FullTestOutput = $false
        IncludeInfrastructure = $true
    }

    "Standard" = @{
        Description = "Empfohlener allgemeiner Handoff inkl. Runtime-Assets, Audio und 3D-Modellen"
        IncludeAudio = $true
        IncludeGraphics = $true
        IncludeBlend = $false
        IncludeTestOutput = $true
        FullTestOutput = $false
        IncludeInfrastructure = $true
    }

    "Audio" = @{
        Description = "Musik-/SFX-/Voice-Bewertung inklusive Audio-Logik"
        IncludeAudio = $true
        IncludeGraphics = $false
        IncludeBlend = $false
        IncludeTestOutput = $false
        FullTestOutput = $false
        IncludeInfrastructure = $false
    }

    "Art" = @{
        Description = "Grafik-/3D-Bewertung inkl. Blender-Quellen, ohne Audio"
        IncludeAudio = $false
        IncludeGraphics = $true
        IncludeBlend = $true
        IncludeTestOutput = $true
        FullTestOutput = $false
        IncludeInfrastructure = $true
    }

    "Full" = @{
        Description = "Vollstaendiger Entwicklungs-Handoff inkl. Audio, Blender und allen Testausgaben"
        IncludeAudio = $true
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

function Test-IsAudioPath {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $Relative = Get-RelativeProjectPath $File.FullName
    $Extension = $File.Extension.ToLowerInvariant()

    if ($AudioExtensions -contains $Extension) {
        return $true
    }

    if ($Relative -like "assets\audio\*" -or
        $Relative -like "assets/audio/*") {
        return $true
    }

    return $false
}

function Test-IsGraphicsAsset {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $Relative = Get-RelativeProjectPath $File.FullName

    if ($Relative -notlike "assets\*" -and
        $Relative -notlike "assets/*") {
        return $false
    }

    if (Test-IsAudioPath $File) {
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

    $Relative = Get-RelativeProjectPath $File.FullName

    return (
        $Relative -like "test-output\*" -or
        $Relative -like "test-output/*"
    )
}

function Test-IsInfrastructurePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    return (
        $RelativePath -like ".github\*" -or
        $RelativePath -like ".github/*" -or
        $RelativePath -like "server\*" -or
        $RelativePath -like "server/*" -or
        $RelativePath -like "installer\*" -or
        $RelativePath -like "installer/*"
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

    # Nur Dateien direkt im Projektstamm
    if ($Relative -match "[\\/]") {
        return $false
    }

    return $true
}

function Test-ShouldIncludeFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
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

    # test-output separat behandeln
    if (Test-IsTestOutputFile $File) {
        return $false
    }

    # Root-Dateien wie project.godot, README, Build/Test-Skripte etc.
    if (Test-IsUsefulRootFile $File) {
        return $true
    }

    # Gemeinsamer Quell-/Dokumentations-/Tool-Bestand
    if (Test-IsCommonProjectPath $Relative) {

        # Im Audio-Modus nur audio-relevante Tools/Tests/Skripte nicht hart filtern:
        # kompletter Code ist klein und hilft bei der Ereignis-/Busanalyse.
        return $true
    }

    # Infrastruktur
    if (Test-IsInfrastructurePath $Relative) {
        return [bool]$Settings.IncludeInfrastructure
    }

    # Assets
    if ($Relative -like "assets\*" -or
        $Relative -like "assets/*") {

        if (Test-IsAudioPath $File) {
            return [bool]$Settings.IncludeAudio
        }

        if (Test-IsGraphicsAsset $File) {

            if (-not [bool]$Settings.IncludeGraphics) {
                return $false
            }

            if ((Test-IsBlendFile $File) -and
                -not [bool]$Settings.IncludeBlend) {
                return $false
            }

            return $true
        }
    }

    # FULL nimmt zusaetzlich weitere nicht ausgeschlossene Projektdateien mit.
    if ($Mode -eq "Full") {
        return $true
    }

    return $false
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

    Copy-Item `
        -LiteralPath $Source `
        -Destination $Destination `
        -Force
}

# ============================================================
# 1. PROJEKTDATEIEN SAMMELN
# ============================================================

Write-Host "[MODE  ] $Mode" -ForegroundColor Green
Write-Host "[INFO  ] $($Settings.Description)" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "Sammle Projektdateien ..." -ForegroundColor Yellow

$AllProjectFiles = Get-ChildItem `
    -Path $ProjectRoot `
    -File `
    -Recurse `
    -Force

$CopiedFiles = 0
$CopiedBytes = [int64]0

foreach ($File in $AllProjectFiles) {

    if (-not (Test-ShouldIncludeFile $File)) {
        continue
    }

    Copy-ProjectFileAbsolute $File.FullName

    $CopiedFiles++
    $CopiedBytes += $File.Length
}

# ============================================================
# 2. TEST-OUTPUT
# ============================================================

if ([bool]$Settings.IncludeTestOutput) {

    $TestOutputRoot = Join-Path $ProjectRoot "test-output"

    if (Test-Path $TestOutputRoot) {

        Write-Host "[TESTS ] test-output" -ForegroundColor Green

        $Cutoff = (Get-Date).AddDays(-$TestOutputDays)

        $TestFiles = Get-ChildItem `
            -Path $TestOutputRoot `
            -File `
            -Recurse

        foreach ($File in $TestFiles) {

            if ($TestOutputAllowedExtensions -notcontains $File.Extension.ToLowerInvariant()) {
                continue
            }

            if (-not [bool]$Settings.FullTestOutput -and
                $File.LastWriteTime -lt $Cutoff) {
                continue
            }

            Copy-ProjectFileAbsolute $File.FullName

            $CopiedFiles++
            $CopiedBytes += $File.Length
        }
    }
}

# ============================================================
# 3. INVENTARE DES GESAMTEN PROJEKTS
#
# Die Inventare werden IMMER erstellt, auch wenn die eigentlichen
# Assets in einem kleinen Modus nicht enthalten sind.
# So ist fuer die Analyse sichtbar, was im Projekt existiert.
# ============================================================

Write-Host "[LISTE ] Audio-/3D-/Grossdatei-Inventar" -ForegroundColor Green

$AudioInventory = Join-Path $TempRoot "_AUDIO_FILES.txt"

Get-ChildItem `
    -Path $ProjectRoot `
    -File `
    -Recurse `
    -ErrorAction SilentlyContinue |
    Where-Object {
        -not (Test-PathContainsExcludedDirectory (Get-RelativeProjectPath $_.FullName)) -and
        $AudioExtensions -contains $_.Extension.ToLowerInvariant()
    } |
    Sort-Object FullName |
    ForEach-Object {

        $Relative = Get-RelativeProjectPath $_.FullName

        "{0}`t{1:N2} KB`t{2}" -f `
            $Relative,
            ($_.Length / 1KB),
            $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    } |
    Set-Content `
        -Path $AudioInventory `
        -Encoding UTF8


$ModelInventory = Join-Path $TempRoot "_3D_ASSETS.txt"

Get-ChildItem `
    -Path $ProjectRoot `
    -File `
    -Recurse `
    -ErrorAction SilentlyContinue |
    Where-Object {
        -not (Test-PathContainsExcludedDirectory (Get-RelativeProjectPath $_.FullName)) -and
        $ModelExtensions -contains $_.Extension.ToLowerInvariant()
    } |
    Sort-Object FullName |
    ForEach-Object {

        $Relative = Get-RelativeProjectPath $_.FullName

        "{0}`t{1:N2} MB`t{2}" -f `
            $Relative,
            ($_.Length / 1MB),
            $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    } |
    Set-Content `
        -Path $ModelInventory `
        -Encoding UTF8


$LargestFilesInventory = Join-Path $TempRoot "_LARGEST_PROJECT_FILES.txt"

Get-ChildItem `
    -Path $ProjectRoot `
    -File `
    -Recurse `
    -ErrorAction SilentlyContinue |
    Where-Object {
        -not (Test-PathContainsExcludedDirectory (Get-RelativeProjectPath $_.FullName))
    } |
    Sort-Object Length -Descending |
    Select-Object -First 100 |
    ForEach-Object {

        $Relative = Get-RelativeProjectPath $_.FullName

        "{0:N2} MB`t{1}" -f `
            ($_.Length / 1MB),
            $Relative
    } |
    Set-Content `
        -Path $LargestFilesInventory `
        -Encoding UTF8

# ============================================================
# 4. GIT-INFORMATIONEN
# ============================================================

$GitExe = Get-Command git -ErrorAction SilentlyContinue

if ($null -ne $GitExe) {

    Write-Host "[GIT   ] Status / Branch / Commit / Log / Diff" -ForegroundColor Green

    Push-Location $ProjectRoot

    try {
        git status --short |
            Out-File `
                (Join-Path $TempRoot "_GIT_STATUS.txt") `
                -Encoding UTF8

        git branch --show-current |
            Out-File `
                (Join-Path $TempRoot "_GIT_BRANCH.txt") `
                -Encoding UTF8

        git rev-parse HEAD |
            Out-File `
                (Join-Path $TempRoot "_GIT_COMMIT.txt") `
                -Encoding UTF8

        git log `
            -n 30 `
            --oneline `
            --decorate |
            Out-File `
                (Join-Path $TempRoot "_GIT_LOG.txt") `
                -Encoding UTF8

        git diff --stat |
            Out-File `
                (Join-Path $TempRoot "_GIT_DIFF_STAT.txt") `
                -Encoding UTF8

        git diff |
            Out-File `
                (Join-Path $TempRoot "_GIT_DIFF.patch") `
                -Encoding UTF8
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

Test-output:
$(if ([bool]$Settings.IncludeTestOutput) {
    if ([bool]$Settings.FullTestOutput) {
        "komplett"
    }
    else {
        "letzte $TestOutputDays Tage"
    }
}
else {
    "nicht enthalten"
})

Audio-Dateien:
$(if ([bool]$Settings.IncludeAudio) { "enthalten" } else { "nicht enthalten; Inventar vorhanden" })

Grafik-/Runtime-Assets:
$(if ([bool]$Settings.IncludeGraphics) { "enthalten" } else { "nicht enthalten; Inventar vorhanden" })

Blender-Quellen:
$(if ([bool]$Settings.IncludeBlend) { "enthalten" } else { "nicht enthalten; Inventar vorhanden" })

Infrastruktur (.github/server/installer):
$(if ([bool]$Settings.IncludeInfrastructure) { "enthalten" } else { "nicht enthalten" })

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
- fertige Windows EXE/MSI
- alte ZIP/7z/RAR-Pakete
- temporaere Caches

Hinweis:
Dies ist ein Entwicklungs-/Analyse-Handoff und kein Backup.
"@

Set-Content `
    -Path $ManifestFile `
    -Value $Manifest `
    -Encoding UTF8

# ============================================================
# 6. DATEILISTE DES HANDOFFS
# ============================================================

$FileList = Join-Path $TempRoot "_FILELIST.txt"

Get-ChildItem `
    -Path $TempRoot `
    -File `
    -Recurse |
    Sort-Object FullName |
    ForEach-Object {

        $Relative = $_.FullName.Substring($TempRoot.Length + 1)

        "{0}`t{1}" -f `
            $Relative,
            $_.Length
    } |
    Set-Content `
        -Path $FileList `
        -Encoding UTF8

# ============================================================
# 7. GROESSENPRUEFUNG
# ============================================================

$StageBytes = (
    Get-ChildItem `
        -Path $TempRoot `
        -File `
        -Recurse |
    Measure-Object `
        -Property Length `
        -Sum
).Sum

if ($null -eq $StageBytes) {
    $StageBytes = 0
}

$StageMB = [math]::Round($StageBytes / 1MB, 2)

Write-Host ""
Write-Host "Dateien: $CopiedFiles" -ForegroundColor White
Write-Host "Unkomprimierte Handoff-Groesse: $StageMB MB" -ForegroundColor White

if ($StageMB -gt 1500) {
    Write-Warning "Das Paket ist groesser als 1,5 GB. FULL/ART mit Blender-Quellen kann sehr gross werden."
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

Remove-Item `
    -Path $TempRoot `
    -Recurse `
    -Force

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
