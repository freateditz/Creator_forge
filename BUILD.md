# Building CreatorForge

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Flutter | 3.47.5 | `flutter --version` to verify |
| Dart | 3.13.4 | bundled with Flutter |
| Node.js | 20+ | browser extension build only |
| Python | 3.10+ | native host tests |
| Xcode | 15+ | macOS builds |
| Visual Studio | 2022 | Windows builds (Community edition is sufficient) |

## macOS build

```bash
flutter pub get
flutter build macos --debug     # debug
flutter build macos --release   # release (requires signing config)
```

The built app is at `build/macos/Build/Products/Release/creator_forge.app`.

## Windows build

### Option A — GitHub Actions CI (no Windows machine required)

Push to `main` or open a PR. The `ci-windows.yml` workflow builds the Windows
release binary and uploads it as a GitHub Actions artifact (`creator_forge_windows_release`).

### Option B — Local Windows build

Requirements: Visual Studio 2022 with "Desktop development with C++" workload installed.

```powershell
flutter pub get
flutter build windows --release
```

Output: `build\windows\x64\runner\Release\creator_forge.exe`

> **Note:** The Windows release build has been verified to compile via CI. It has not been
> manually run and tested on a physical Windows machine. Runtime verification remains a blocker
> before public release.

## Running all tests

```bash
# Dart unit tests (236 tests)
flutter test

# Static analysis
flutter analyze

# Format check
dart format --set-exit-if-changed lib/ test/

# Browser extension tests (65 tests)
cd browser-extension && npm ci && npm test

# Python native host unit tests (24 tests)
python3 native-host/test_native_host.py

# Python native host integration tests (12 tests)
python3 native-host/test_e2e.py
```

## Building the browser extension

```bash
cd browser-extension
npm ci
npm run build       # outputs to browser-extension/dist/
```

Load `browser-extension/dist/` as an unpacked extension in Chrome/Edge.
See [BROWSER_EXTENSION.md](BROWSER_EXTENSION.md) for the full setup flow.

## Known limitations

- **Windows runtime**: The Windows release build compiles via CI (`windows-latest` runner).
  Manual end-to-end testing on a physical Windows machine has not been completed.
- **Signing**: Neither the macOS nor Windows build is code-signed. macOS Gatekeeper will
  block the release app unless signed and notarized. Windows SmartScreen will warn on
  first run without a signed EV certificate.
- **Python interpreter on Windows**: The demucs and bg-removal workers spawn a managed
  Python venv. The venv is created on first use if Python 3.10+ is in PATH.
- **AI models**: htdemucs (~83 MB) and isnet-general-use (~177 MB) are downloaded on first
  use inside CreatorForge. They are not included in the build artifact.
