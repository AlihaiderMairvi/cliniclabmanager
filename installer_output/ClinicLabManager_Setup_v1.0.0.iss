; =============================================================================
; Clinic Lab Manager — Inno Setup Installer Script
; =============================================================================

#define MyAppName "Clinic Lab Manager"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Ali Haider"
#define MyAppExeName "cliniclabmanager.exe"
#define MyAppSourceDir "D:\Flutter-Projects\cliniclabmanager\build\windows\x64\runner\Release"
#define MyIcon "D:\Flutter-Projects\cliniclabmanager\windows\runner\resources\app_icon.ico"

[Setup]
AppId={{B7A3F9D2-4C81-4E56-9B2A-CLINICLAB0001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=D:\Flutter-Projects\cliniclabmanager\installer_output
OutputBaseFilename=ClinicLabManager_Setup_v1.0.0
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile={#MyIcon}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
; Main executable
Source: "{#MyAppSourceDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; Core DLLs
Source: "{#MyAppSourceDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\dartjni.dll"; DestDir: "{app}"; Flags: ignoreversion

; Plugin DLLs
Source: "{#MyAppSourceDir}\pdfium.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\printing_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\share_plus_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion

; SQLite (critical — app crashes without it)
Source: "{#MyAppSourceDir}\sqlite3.dll"; DestDir: "{app}"; Flags: ignoreversion

; Data folder (recursive)
Source: "{#MyAppSourceDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent