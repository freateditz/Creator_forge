; CreatorForge — Inno Setup installer script
; Version: 1.0.0
;
; Prerequisites:
;   - Inno Setup 6.3+ (https://jrsoftware.org/isinfo.php)
;   - Flutter release build at: ..\..\build\windows\x64\runner\Release\
;   - PowerShell scripts in:    installer\windows\scripts\
;
; Build command (from repo root, Inno Setup in PATH):
;   iscc installer\windows\creator_forge.iss
;
; Output:  installer\windows\Output\CreatorForge-1.0.0-Setup.exe
;
; ── What this installer does ──────────────────────────────────────────────────
;   1. Copies the Flutter executable and all DLLs (no duplicate entries).
;   2. Copies flutter_assets (data\flutter_assets) which includes the Python
;      worker scripts bundled by Flutter.
;   3. Copies the compiled native-host exe to {app}\NativeHost\ (if built by CI).
;   4. Copies the browser-extension/dist/ directory to {app}\browser-extension\dist\.
;   5. Copies the Python host script + PowerShell helper scripts.
;   6. Runs install_native_host.ps1 post-install to:
;        a. Prefer the compiled exe; fall back to bat wrapper if Python found.
;        b. Write the NM manifest with a placeholder origin.
;        c. Register Chrome + Edge HKCU registry keys using reg.exe /ve.
;        d. Read back and verify the registry values.
;   7. Creates Start Menu shortcut and optional desktop shortcut.
;   8. On uninstall: runs uninstall_native_host.ps1 then removes all files.
;
;   The user completes browser setup by opening CreatorForge → Browser
;   Integration, which detects the browser, guides extension loading, and
;   updates the registry with the real extension ID automatically.
;
; ── NOT bundled (user must install separately) ────────────────────────────────
;   - Python 3.10+ interpreter (required for AI features + native host)
;   - yt-dlp                  (required for video downloading)
;   - FFmpeg / ffprobe        (required for audio conversion + AI features)
;   - AI model weights        (installed on-demand from within the app)
;
; ── Code signing ─────────────────────────────────────────────────────────────
;   Not configured here.  Unsigned builds will trigger Windows SmartScreen.
;   See WINDOWS_BUILD.md for signing options before public distribution.

#define AppName        "CreatorForge"
#define AppVersion     "1.0.0"
#define AppPublisher   "CreatorForge"
#define AppURL         "https://github.com/your-org/creator_forge"
#define AppExeName     "creator_forge.exe"
#define NativeHostName "com.creatorforge.native_host"

; Paths are relative to the location of this .iss file.
#define BuildDir    "..\..\build\windows\x64\runner\Release"
#define NativeHost  "..\..\native-host"
#define ExtDist     "..\..\browser-extension\dist"
#define Scripts     "scripts"

[Setup]
AppId={{6A3F1B2C-9D4E-4A5B-8C7F-2E1D0A3B4C5D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
; {autopf} expands to Program Files on elevated installs or LocalAppData\Programs
; when running without elevation (PrivilegesRequired=lowest).
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Allow the user to elevate if they want a system-wide install, but default
; to per-user so no admin rights are required.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=Output
OutputBaseFilename=CreatorForge-{#AppVersion}-Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; Uninstaller metadata.
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
; Version info embedded in the installer executable.
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Installer
; Code signing — uncomment when a certificate is configured:
; SignTool=signtool sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 /f "$p"
; SignedUninstallerDir={tmp}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; ── Flutter application ───────────────────────────────────────────────────────
; Use *.exe and *.dll with recursesubdirs so we don't have to enumerate every
; DLL individually (which would create duplicate-entry warnings).
Source: "{#BuildDir}\{#AppExeName}";   DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll";           DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\data\*";          DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; ── Native messaging host ─────────────────────────────────────────────────────
; Python script (always bundled for transparency / source reference).
Source: "{#NativeHost}\creator_forge_host.py"; DestDir: "{userappdata}\CreatorForge\NativeHost"; Flags: ignoreversion

; Compiled exe (preferred host; produced by the CI PyInstaller build step and
; copied into the release tree by the CI "Copy native-host exe" step).
; skipifsourcedoesntexist allows local developer builds without PyInstaller.
Source: "{#BuildDir}\NativeHost\creator_forge_native_host.exe"; \
  DestDir: "{app}\NativeHost"; \
  Flags: ignoreversion skipifsourcedoesntexist

; ── Browser extension ─────────────────────────────────────────────────────────
; Built extension files so the in-app wizard can open Explorer to the dist/
; folder and guide the user through Load unpacked without needing the source tree.
Source: "{#ExtDist}\*"; DestDir: "{app}\browser-extension\dist"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

; ── Post-install helper scripts ───────────────────────────────────────────────
; These are copied to {app}\scripts so [Run]/[UninstallRun] can find them.
Source: "{#Scripts}\install_native_host.ps1";   DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "{#Scripts}\uninstall_native_host.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}";           Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";     Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
; Register the native messaging host after install.
; The script finds Python, writes a bat wrapper, writes the NM manifest
; (with empty allowed_origins — user must run the script again with their
; extension ID), and registers Chrome + Edge HKCU keys.
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\install_native_host.ps1"""; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Registering browser integration..."

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\uninstall_native_host.ps1"""; \
  Flags: runhidden waituntilterminated; \
  RunOnceId: "UnregisterNativeHost"

[UninstallDelete]
; Remove the native host installation directory (bat wrapper + manifest).
Type: filesandordirs; Name: "{userappdata}\CreatorForge\NativeHost"
; NOTE: User data ({userappdata}\creator_forge — downloads, models, database)
; is intentionally preserved on uninstall.

[Code]
// ── Pre-install checks ────────────────────────────────────────────────────────
//
// We cannot check for yt-dlp, FFmpeg, or specific Python packages here because
// Inno Setup runs in a constrained environment.  We check only for Python 3
// to give an actionable warning about AI features being unavailable.
// The main app shows per-feature availability in its Settings screen.

function PythonAvailable(): Boolean;
var
  ResultCode: Integer;
begin
  // Try 'python' first (python.org MSI sets this), then 'py' (Python Launcher).
  Result := Exec(ExpandConstant('{sys}\cmd.exe'), '/C python --version',
                 '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
             and (ResultCode = 0);
  if not Result then
    Result := Exec(ExpandConstant('{sys}\cmd.exe'), '/C py -3 --version',
                   '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
               and (ResultCode = 0);
end;

function InitializeSetup(): Boolean;
var
  MsgResult: Integer;
begin
  Result := True;
  if not PythonAvailable() then begin
    MsgResult := MsgBox(
      'Python 3.10 or later was not found.' + #13#10
      + #13#10
      + 'Python is required for:' + #13#10
      + '  - AI vocal separation' + #13#10
      + '  - AI background removal' + #13#10
      + '  - Browser extension integration' + #13#10
      + #13#10
      + 'You can install Python from https://python.org and install these' + #13#10
      + 'features later from the CreatorForge Settings screen.' + #13#10
      + #13#10
      + 'Continue without Python?',
      mbConfirmation, MB_YESNO
    );
    if MsgResult = IDNO then
      Result := False;
  end;
end;
