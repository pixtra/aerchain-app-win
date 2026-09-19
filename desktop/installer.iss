; AerChain V0 (Demo) — Windows installer (Inno Setup 6).
; Build order on the Windows machine:
;   1. desktop.bat        (environment; creates dist via build below)
;   2. build-exe.bat      (produces dist\AerchainDesktop.exe)
;   3. (optional, for bundled prerequisites) place next to this file:
;        OllamaSetup.exe    from https://ollama.com/download
;        TesseractSetup.exe = UB-Mannheim w64 setup from
;                             https://github.com/UB-Mannheim/tesseract/wiki
;      Missing files are simply skipped (see #if guards below).
;   4. Open this file in Inno Setup 6 and press Ctrl+F9 (Compile).
; Output: installer-out\Setup-AerChain-V0-Demo.exe — that single file is the handoff.
; Per-user install (no admin for OUR app; the prerequisite installers below may
; show their own UAC prompt — normal, accept it, or untick them to skip).

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
#if FileExists("OllamaSetup.exe")
Source: "OllamaSetup.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
#endif
#if FileExists("TesseractSetup.exe")
Source: "TesseractSetup.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
#endif

[Tasks]
Name: desktopicon; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"
Name: installollama; Description: "Install Ollama (offline AI — else use Groq cloud)"; GroupDescription: "Prerequisites (untick to skip):"
Name: installtess; Description: "Install Tesseract OCR (photo/scan uploads)"; GroupDescription: "Prerequisites (untick to skip):"

[Icons]
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
#if FileExists("OllamaSetup.exe")
Filename: "{tmp}\OllamaSetup.exe"; Parameters: "/SILENT"; StatusMsg: "Installing Ollama (offline AI)..."; Tasks: installollama; Flags: waituntilterminated
#endif
#if FileExists("TesseractSetup.exe")
Filename: "{tmp}\TesseractSetup.exe"; Parameters: "/VERYSILENT"; StatusMsg: "Installing Tesseract OCR..."; Tasks: installtess; Flags: waituntilterminated
#endif
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
