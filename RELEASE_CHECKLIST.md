# Release Checklist

Complete every item before publishing a public release.

---

## Pre-release

- [ ] Version number updated in `pubspec.yaml` (e.g., `1.0.1+2`)
- [ ] `dart format --set-exit-if-changed lib/ test/` passes with no changes
- [ ] `flutter analyze` reports 0 issues
- [ ] All 236 Dart unit tests pass (`flutter test`)
- [ ] All 65 TypeScript extension tests pass (`cd browser-extension && npm test`)
- [ ] All 41 Python native host unit tests pass (`python3 native-host/test_native_host.py`)
- [ ] All 16 Python native host integration tests pass (`python3 native-host/test_e2e.py`)
- [ ] macOS debug build succeeds (`flutter build macos --debug`)
- [ ] Windows release build succeeds (CI workflow `ci-windows.yml` green)
- [ ] `THIRD_PARTY_NOTICES.md` is current (new dependencies added?)
- [ ] No secrets, credentials, or personal paths committed to repository

---

## macOS packaging

- [ ] macOS release build succeeds (`flutter build macos --release`)
- [ ] App bundle launches and all features function on a clean macOS install
- [ ] Code signing configured (Developer ID Application certificate)
- [ ] App notarized with Apple (`xcrun notarytool`)
- [ ] Gatekeeper passes on a machine that has never run the app

---

## Windows packaging

- [ ] Windows release build artifact downloaded from CI
- [ ] `creator_forge.exe` launches from the artifact directory
- [ ] FFmpeg is available (bundled or documented install path)
- [ ] yt-dlp is available (bundled or documented install path)
- [ ] Python 3.10+ is available for AI features (documented)
- [ ] Application data writes correctly to `%APPDATA%\creator_forge\`
- [ ] IPC conn file is written and removed cleanly on start/exit
- [ ] Code signing configured (EV certificate recommended to avoid SmartScreen)

---

## Browser extension

- [ ] Extension built with `npm run build`
- [ ] `browser-extension/dist/manifest.json` version updated
- [ ] Extension loads without errors in Chrome (`chrome://extensions/`)
- [ ] Extension loads without errors in Edge
- [ ] Native host install script tested on macOS: `bash install_macos.sh <ID>`
- [ ] Native host install script tested on Windows: `install_windows.ps1 <ID>`
- [ ] Extension popup shows "Connected" when CreatorForge is running
- [ ] Extension popup shows "CreatorForge not running" when it isn't
- [ ] Extension ID set in NM manifest (no placeholder `__EXTENSION_ID__`)

---

## End-to-end browser workflow (manual — macOS)

- [ ] Open test page with video element
- [ ] Extension detects video and shows it in popup
- [ ] "Send to CreatorForge" enqueues a download task
- [ ] Download task appears in the Browser Downloads screen
- [ ] Download completes and output file is readable
- [ ] Cancellation works from the queue

---

## Security

- [ ] No credentials or tokens appear in logs
- [ ] URL validation rejects non-HTTP/HTTPS schemes
- [ ] Localhost/loopback/private-IP URLs are rejected by `BrowserRequestHandler`
- [ ] Extension ID is set to the actual extension ID (not a wildcard)
- [ ] No DRM bypass code present
- [ ] No browsing history collection
- [ ] THIRD_PARTY_NOTICES.md accurate for all AI model licenses

---

## AI features (manual smoke test — skip in routine CI)

- [ ] Vocal separation: short clip produces `Vocals.wav` and `Instrumental.wav`
- [ ] Background removal: test PNG has transparent background (RGBA output)
- [ ] htdemucs CC BY-NC license notice visible in UI
- [ ] isnet model license notice visible in UI

---

## Documentation

- [ ] `README.md` platform support table is accurate
- [ ] `BUILD.md` steps verified on a clean machine
- [ ] `INSTALLATION.md` steps verified on a clean Windows machine
- [ ] `BROWSER_EXTENSION.md` extension ID steps verified
- [ ] Known limitations documented

---

## Post-release

- [ ] Git tag created: `git tag v1.0.0 && git push origin v1.0.0`
- [ ] GitHub Release created with the Windows build artifact attached
- [ ] macOS `.app` distributed via agreed channel (direct download / notarized DMG)
- [ ] Release notes written (features, fixes, known issues)
- [ ] Test installation from the published artifact on a machine without a dev environment
