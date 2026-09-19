; AerChain V0 (Demo) — Windows installer (Inno Setup 6).
; Build order on the Windows machine:
;   1. desktop.bat        (environment; creates dist via build below)
;   2. build-exe.bat      (produces dist\AerchainDesktop.exe)
;   3. Open this file in Inno Setup 6 and press Ctrl+F9 (Compile).
; Output: installer-out\Setup-AerChain-V0-Demo.exe — that single file is the handoff.
; Per-user install (no admin). Includes an uninstaller automatically.

#define MyAppName "AerChain V0 (Demo)"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "Aerchain"
#define MyAppExeName "AerchainDesktop.exe"

[Setup]
AppId={{73B43431-CD61-41CF-993B-E4DDB3878B53}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\AerChain V0 Demo
PrivilegesRequired=lowest
OutputDir=installer-out
OutputBaseFilename=Setup-AerChain-V0-Demo
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
UninstallDisplayName={#MyAppName}

[Files]
Source: "dist\AerchainDesktop.exe"; DestDir: "{app}"; Flags: ignoreversion

[Tasks]
Name: desktopicon; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"

[Icons]
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
