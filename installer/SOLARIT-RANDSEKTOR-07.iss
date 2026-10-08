#ifndef AppVersion
  #define AppVersion "0.36.28"
#endif

#define AppName "SOLARIT: RANDSEKTOR 07"
#define AppExe "SOLARIT-RANDSEKTOR-07.exe"

[Setup]
AppId={{B42C780A-68DF-4ED5-8D46-2B96F57DE539}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=DieListe01
AppPublisherURL=https://github.com/DieListe01
AppSupportURL=https://github.com/DieListe01
DefaultDirName={localappdata}\Programs\SOLARIT-RANDSEKTOR-07
DefaultGroupName=SOLARIT - RANDSEKTOR 07
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
OutputDir=..\build
OutputBaseFilename=SOLARIT-RANDSEKTOR-07-Setup-{#AppVersion}
UninstallDisplayIcon={app}\{#AppExe}
LicenseFile=..\LICENSE
InfoBeforeFile=..\README.md
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
Uninstallable=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "..\build\SOLARIT-RANDSEKTOR-07.exe"; DestDir: "{app}"; Flags: ignoreversion restartreplace
Source: "..\build\Spielstart.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\GODOT-LICENSES.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\SOLARIT - RANDSEKTOR 07"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\SOLARIT - RANDSEKTOR 07"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "SOLARIT: RANDSEKTOR 07 starten"; Flags: postinstall nowait skipifsilent
