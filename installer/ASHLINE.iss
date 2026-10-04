#ifndef AppVersion
  #define AppVersion "0.35"
#endif

#define AppName "ASHLINE - Das Veyra-Becken"
#define AppExe "ASHLINE.exe"

[Setup]
AppId={{B42C780A-68DF-4ED5-8D46-2B96F57DE539}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=DieListe01
AppPublisherURL=https://github.com/DieListe01
AppSupportURL=https://github.com/DieListe01
DefaultDirName={localappdata}\Programs\ASHLINE
DefaultGroupName=ASHLINE
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
OutputDir=..\build
OutputBaseFilename=ASHLINE-Setup-{#AppVersion}
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
Source: "..\build\ASHLINE.exe"; DestDir: "{app}"; Flags: ignoreversion restartreplace
Source: "..\build\Spielstart.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\GODOT-LICENSES.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\ASHLINE"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\ASHLINE"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "ASHLINE starten"; Flags: postinstall nowait skipifsilent
