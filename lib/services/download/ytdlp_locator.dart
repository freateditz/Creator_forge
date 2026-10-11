import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';

class YtDlpLocator {
  YtDlpLocator._();

  static final YtDlpLocator instance = YtDlpLocator._();

  final _log = AppLogger.get('YtDlpLocator');
  String? _resolvedPath;

  List<String> get _candidates {
    // Managed bin dir is checked first so auto-provisioned exe takes priority.
    final managedExe = Platform.isWindows
        ? p.join(AppConfig.instance.binDir, 'yt-dlp.exe')
        : p.join(AppConfig.instance.binDir, 'yt-dlp');

    final candidates = <String>[
      managedExe,
      'yt-dlp',
      '/opt/homebrew/bin/yt-dlp',
      '/usr/local/bin/yt-dlp',
      '/usr/bin/yt-dlp',
      '/Library/Frameworks/Python.framework/Versions/3.14/bin/yt-dlp',
      '/Library/Frameworks/Python.framework/Versions/3.13/bin/yt-dlp',
      '/Library/Frameworks/Python.framework/Versions/3.12/bin/yt-dlp',
      '/Library/Frameworks/Python.framework/Versions/3.11/bin/yt-dlp',
    ];

    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
      final appData = Platform.environment['APPDATA'] ?? '';
      candidates.addAll([
        // Documented manual install location (see INSTALLATION.md).
        r'C:\Program Files\CreatorForge\bin\yt-dlp.exe',
        // Standalone yt-dlp release binary extracted to Program Files.
        r'C:\Program Files\yt-dlp\yt-dlp.exe',
        // WinGet default install location (version-suffix varies).
        if (localAppData.isNotEmpty)
          '$localAppData\\Microsoft\\WinGet\\Packages\\yt-dlp.yt-dlp_Microsoft.Winget.Source_8wekyb3d8bbwe\\yt-dlp.exe',
        // Python launcher installs (python.org MSI).
        if (localAppData.isNotEmpty) ...[
          '$localAppData\\Programs\\Python\\Python313\\Scripts\\yt-dlp.exe',
          '$localAppData\\Programs\\Python\\Python312\\Scripts\\yt-dlp.exe',
          '$localAppData\\Programs\\Python\\Python311\\Scripts\\yt-dlp.exe',
          '$localAppData\\Programs\\Python\\Python310\\Scripts\\yt-dlp.exe',
        ],
        // pip --user install.
        if (appData.isNotEmpty) ...[
          '$appData\\Python\\Python313\\Scripts\\yt-dlp.exe',
          '$appData\\Python\\Python312\\Scripts\\yt-dlp.exe',
          '$appData\\Python\\Python311\\Scripts\\yt-dlp.exe',
        ],
        // Scoop install.
        if (Platform.environment['USERPROFILE'] != null)
          '${Platform.environment["USERPROFILE"]}\\scoop\\shims\\yt-dlp.exe',
        // Chocolatey install.
        r'C:\ProgramData\chocolatey\bin\yt-dlp.exe',
        // Last resort: rely on PATH.
        'yt-dlp.exe',
      ]);
    }

    return candidates;
  }

  Future<String?> resolve() async {
    if (_resolvedPath != null) return _resolvedPath;
    for (final candidate in _candidates) {
      try {
        final result = await Process.run(candidate, [
          '--version',
        ], runInShell: false);
        if (result.exitCode == 0) {
          _resolvedPath = candidate;
          _log.info('yt-dlp found at: $candidate');
          return candidate;
        }
      } catch (_) {}
    }
    _log.warning('yt-dlp not found in any candidate location.');
    return null;
  }

  Future<bool> isAvailable() async => (await resolve()) != null;

  Future<String?> getVersion() async {
    final path = await resolve();
    if (path == null) return null;
    try {
      final result = await Process.run(path, ['--version'], runInShell: false);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (e) {
      _log.warning('Could not get yt-dlp version.', e);
    }
    return null;
  }

  void invalidate() => _resolvedPath = null;
}
