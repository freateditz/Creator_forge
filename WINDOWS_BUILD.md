# Windows Build & Distribution Guide

## Prerequisites

| Tool | Version | Where to get it |
|------|---------|-----------------|
| Flutter | 3.47.5 | `flutter.dev` or `fvm` |
| Visual Studio | 2022 | With "Desktop development with C++" workload |
| Windows SDK | 10.0.19041+ | Included with Visual Studio installer |
| Inno Setup | 6.3+ | https://jrsoftware.org/isinfo.php |
| Node.js | 20+ | `nodejs.org` (browser extension build only) |
| Python | 3.10–3.12 | `python.org` MSI installer |

## Building the Flutter app

```powershell
# From repo root
flutter pub get
flutter build windows --release
# Output: build\windows\x64\runner\Release\
```

## Building the browser extension

```powershell
cd browser-extension
npm ci
npm run build
# Output: browser-extension\dist\
```

## Building the installer

```powershell
# Requires: Inno Setup in PATH (or use full path to iscc.exe)
iscc installer\windows\creator_forge.iss
# Output: installer\windows\Output\CreatorForge-1.0.0-Setup.exe
```

The installer packages:
- Flutter app + DLLs from `build\windows\x64\runner\Release\`
- Native messaging host Python script (`native-host\creator_forge_host.py`)
- PowerShell helper scripts (`installer\windows\scripts\`)

## Code Signing

**Current status: unsigned.** Unsigned installers trigger Windows SmartScreen.
Users will see "Windows protected your PC" and must click "More info → Run anyway".

### Options

**Self-signed (developer testing only)**
```powershell
# Generate a self-signed cert (expires in 1 year, not trusted by Windows by default)
$cert = New-SelfSignedCertificate -Type CodeSigningCert `
    -Subject "CN=CreatorForge" -CertStoreLocation Cert:\CurrentUser\My
```
This silences SmartScreen on the developer machine only.

**EV Code Signing Certificate (recommended for public distribution)**
- Purchase from a Certificate Authority (DigiCert, Sectigo, GlobalSign)
- EV certs eliminate SmartScreen immediately upon first run
- Standard OV certs reduce SmartScreen reputation warnings after sufficient
  installs accumulate through Microsoft's reputation system

**Signing the installer once a cert is available:**
```powershell
# Using signtool (part of Windows SDK):
signtool sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 `
              /n "Your Publisher Name" `
              installer\windows\Output\CreatorForge-1.0.0-Setup.exe
```

To enable automatic signing during `iscc` compilation, uncomment the `SignTool=`
line in `installer\windows\creator_forge.iss` and configure Inno Setup's signing
tool (Tools → Configure Sign Tools).

## Post-install: Registering the browser extension

The installer runs `install_native_host.ps1` which registers the native messaging
host with Chrome and Edge using an **empty `allowed_origins`** list (no extension
ID is known at install time).

After the user installs the browser extension from the Chrome Web Store, they must
re-run the registration with their extension ID:

```powershell
# Run from an elevated PowerShell or directly as the user
"$Env:ProgramFiles\CreatorForge\scripts\install_native_host.ps1" `
    -ExtensionId "abcdefghijklmnopabcdefghijklmnop"
```

The extension ID is a 32-character lowercase string visible in Chrome at
`chrome://extensions` (enable "Developer mode" to see it).

## Windows Compatibility Statement

**The Windows release build is compiled and verified via GitHub Actions CI**
(see `.github/workflows/ci-windows.yml`) using `windows-latest` runners.

**Manual smoke testing on a physical or virtual Windows machine has not been
performed.** Before public distribution, run the Windows smoke-test checklist
in `docs/windows_smoke_test.md`.

No claim of Windows compatibility is made beyond: the `flutter build windows
--release` command succeeds in CI and the resulting artifact is uploaded.
