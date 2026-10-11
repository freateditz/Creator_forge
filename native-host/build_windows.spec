# -*- mode: python ; coding: utf-8 -*-
#
# PyInstaller spec for creator_forge_native_host.exe
#
# Build command (Windows, from the native-host/ directory):
#   pyinstaller build_windows.spec
#
# Output:
#   native-host/dist/creator_forge_native_host.exe
#
# The Inno Setup installer copies this file to:
#   {app}\NativeHost\creator_forge_native_host.exe
#
# Chrome/Edge's Native Messaging requires a proper .exe.  The bat wrapper
# approach works only when Python is installed and may break binary stdio.
# This exe bundles a minimal Python runtime and requires no external install.
#
# Binary stdio is preserved:
#   - The spec disables the console only for GUI apps; for NM the window must
#     be hidden without redirecting stdio.  We use windowed=False (console=True)
#     to keep stdin/stdout accessible, and configure msvcrt in the host script.
#   - No output goes to stdout except the Native Messaging protocol frames.
#   - All log output goes to stderr.

block_cipher = None

a = Analysis(
    ['creator_forge_host.py'],
    pathex=['.'],
    binaries=[],
    datas=[],
    hiddenimports=[
        'json',
        'struct',
        'socket',
        'os',
        'sys',
        'traceback',
        'time',
        'msvcrt',
    ],
    hookspath=[],
    runtime_hooks=[],
    excludes=[
        'tkinter',
        'matplotlib',
        'numpy',
        'PIL',
        'scipy',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    name='creator_forge_native_host',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,       # UPX can break AV; leave disabled for distribution
    # console=True keeps stdin/stdout accessible for Native Messaging.
    # windowed=False is the same thing; the process has no visible window but
    # the stdio handles are valid.
    console=True,
    # Prevent a console window from appearing when Chrome launches the host.
    # On Windows this is achieved by using the DETACHED_PROCESS flag in the
    # manifest, but PyInstaller + console=True already avoids a visible window
    # when launched from Chrome (which sets CREATE_NO_WINDOW).
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
