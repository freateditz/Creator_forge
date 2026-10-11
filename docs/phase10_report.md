# Phase 10 — Windows Release Candidate: Completion Report

---

## 1. Did GitHub Actions actually run?

**No.** The repository had no `.git` directory at the start of this phase — it
was a local project directory without version control. A git repository has
been initialized (`git init`), the initial commit has been made on branch `main`
(197 files), but **no GitHub remote has been configured** and no workflow has
been triggered.

**To connect to GitHub and trigger CI:**
```bash
# Create a new repo at github.com, then:
git remote add origin https://github.com/<your-org>/creator_forge.git
git push -u origin main
```

Once pushed, GitHub Actions will automatically trigger both
`.github/workflows/ci-macos.yml` and `.github/workflows/ci-windows.yml` on
the `main` branch.

---

## 2. Final Windows CI result and workflow URL

**Not available.** CI has not run yet — no remote exists.

The Windows CI workflow (`.github/workflows/ci-windows.yml`) was updated in
this phase to add:

- A build-output verification step (`creator_forge.exe`, `flutter_windows.dll`,
  `data/flutter_assets` all present)
- Inno Setup 6.3.3 installation via Chocolatey
- Installer compilation: `iscc installer\windows\creator_forge.iss`
- Installer artifact upload: `CreatorForge-1.0.0-Setup.exe` (7-day retention)

The installer step will fail if the Flutter build step produced incomplete
output. The verification step before it catches this early.

---

## 3. Did `flutter build windows --release` pass on Windows?

**Not verified.** The build environment is macOS arm64; `flutter build windows`
is not available on macOS. The Flutter Windows runner source files
(`windows/runner/*.cpp`, `windows/CMakeLists.txt`) are standard Flutter-generated
code unchanged from `flutter create` defaults. No Windows-specific Dart code has
been written that would require validation beyond what the macOS analyzer covers.

What IS verified:
- `flutter analyze`: no issues (0 errors, 0 warnings, 0 hints)
- `flutter test`: 236 tests passed
- All 197 source files compile cleanly on Dart 3.13.4

What is NOT verified without a Windows runner:
- MSVC compilation of the C++ runner
- DLL resolution at runtime
- `%APPDATA%\creator_forge\` path creation
- IPC TCP server binding on loopback
- Windows-specific process lifecycle

---

## 4. Did the Inno Setup installer compile?

**Not verified locally.** Inno Setup is a Windows-only tool. The installer
script (`installer/windows/creator_forge.iss`) was audited and fixed in Phase 9
(removed duplicate DLL entry, fixed `{src}` bug, moved scripts to `[Files]`).

In Phase 10, `installer/windows/scripts/install_native_host.ps1` was rewritten
to fix a security regression: it no longer writes `allowed_origins = @()`. It
now creates only the Python bat wrapper at install time and defers manifest/
registry registration to a second call with the extension ID.

The CI workflow will compile the installer after `flutter build windows --release`
and upload the result as `CreatorForge-1.0.0-Setup.exe`.

---

## 5. Where verified artifacts were produced

| Artifact | Location | Status |
|----------|----------|--------|
| Windows build | `build/windows/x64/runner/Release/` | Not built (macOS) |
| Windows installer | `installer/windows/Output/CreatorForge-1.0.0-Setup.exe` | Not compiled (Windows-only) |
| Browser extension | `browser-extension/dist/` | ✅ Built and tested locally |
| macOS debug build | macOS-only via `flutter build macos --debug` | Available on this machine |

---

## 6. Which dependencies are bundled vs installed separately

| Dependency | Bundled? | Notes |
|------------|----------|-------|
| Flutter runtime + DLLs | ✅ Bundled | Copied by installer from build output |
| Flutter assets + data | ✅ Bundled | `data/` directory in release build |
| Python worker scripts | ✅ Bundled | In `data/flutter_assets/` (Flutter asset) |
| Native messaging host | ✅ Bundled | `creator_forge_host.py` → `%APPDATA%\CreatorForge\NativeHost\` |
| Browser extension | ✅ Bundled (manual load) | User loads from `dist/` in Chrome/Edge |
| Python 3.10+ interpreter | ❌ User installs | Required for AI + native host |
| FFmpeg + ffprobe | ❌ User installs | Required for audio processing |
| yt-dlp | ❌ User installs | Required for video downloading |
| AI model weights | ❌ On-demand | Downloaded on first use, cached locally |
| Python packages (demucs, rembg) | ❌ On-demand | Installed into app-managed venv on first AI use |

---

## 7. Was a clean Windows installation tested?

**No.** No Windows physical or virtual machine was available. The smoke-test
checklist is documented at `docs/windows_smoke_test.md` and must be completed
before public distribution.

---

## 8. Actual smoke-test results

| Workflow | Result | Notes |
|----------|--------|-------|
| Download manager (URL validation, queue, cancel) | ❌ Not tested | No Windows |
| Audio extraction (FFmpeg) | ❌ Not tested | No Windows |
| Vocal separation (demucs) | ❌ Not tested | No Windows |
| Background removal (rembg) | ❌ Not tested | No Windows |
| Browser extension popup | ❌ Not tested | No Windows |
| Native Messaging (real Windows host) | ❌ Not tested | No Windows |
| IPC roundtrip (macOS, unit tests) | ✅ 16 e2e tests passed | TCP + Unix socket |

All native-host protocol tests (41 unit + 16 e2e) run on macOS and cover the
cross-platform NM framing and IPC logic. Windows-specific binary mode
(`msvcrt.setmode`) is covered in unit tests but not verified end-to-end.

---

## 9. Was uninstall behavior verified?

**No.** The uninstaller logic was audited:
- `uninstall_native_host.ps1` removes only Chrome/Edge HKCU keys for the host name
- `[UninstallDelete]` in the .iss file removes only `%APPDATA%\CreatorForge\NativeHost\`
- User data (`%APPDATA%\creator_forge\`) is intentionally preserved
- These behaviors are in the smoke-test checklist but not manually verified

---

## 10. Remaining blockers to distribution

| Blocker | Severity | Action required |
|---------|----------|----------------|
| No GitHub remote / CI has never run | **Critical** | Push to GitHub, verify both workflows green |
| `flutter build windows --release` not verified | **Critical** | Wait for CI green or test on Windows VM |
| Installer not compiled | **Critical** | Verify CI compiles installer successfully |
| No Windows smoke test | **Critical** | Run `docs/windows_smoke_test.md` checklist |
| Installer unsigned (SmartScreen warning) | High | Obtain EV code signing cert for distribution |
| Browser extension icons are 1×1 placeholders | High | Create real icons before store submission |
| Windows native-host e2e test not run on Windows | Medium | Run on Windows after CI passes |
| npm audit: 7 devDependency vulnerabilities | Low | Build-time only; not shipped in extension |
| Instagram / Pinterest / Converter placeholders | Low | Documented as deferred |

---

## Changes made in Phase 10

| File | Change |
|------|--------|
| `.github/workflows/ci-windows.yml` | Added build verification, Inno Setup install + compile, installer artifact upload |
| `installer/windows/scripts/install_native_host.ps1` | Rewrote: no longer writes empty `allowed_origins`; Phase 1 (wrapper only) vs Phase 2 (with extension ID) |
| `INSTALLATION.md` | Updated for installer existence, SmartScreen note, extension registration workflow |
| `RELEASE_CHECKLIST.md` | Fixed stale test counts (24→41 unit, 12→16 e2e) |
| `.gitignore` | Added `node_modules/`, `dist/`, `installer/Output/`, `__pycache__/`, Windows flutter generated files |
| `lib/services/ffmpeg/ffmpeg_service.dart` | Fixed misleading "Bundled" comment |
| `lib/services/download/ytdlp_locator.dart` | Fixed misleading "Bundled" comment |
| Git repository | Initialized; initial commit b382832 on branch `main` (197 files) |

---

## To trigger CI

```bash
# 1. Create a GitHub repo (github.com/new)
# 2. Push:
git remote add origin https://github.com/<your-org>/creator_forge.git
git push -u origin main

# 3. Monitor workflows:
gh run list --workflow ci-windows.yml
gh run view <run-id> --log
```

The Windows workflow will produce two artifacts:
- `creator_forge_windows_release` — Flutter release build directory
- `CreatorForge-1.0.0-Setup.exe` — Inno Setup installer (unsigned)
