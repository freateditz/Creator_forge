import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';

enum InstallStage {
  findingPython,
  creatingEnvironment,
  installingDependencies,
  copyingWorker,
  verifying,
  complete,
}

class InstallProgress {
  final InstallStage stage;
  final String? detail;

  const InstallProgress(this.stage, {this.detail});

  String get label => switch (stage) {
    InstallStage.findingPython => 'Finding Python 3.10+…',
    InstallStage.creatingEnvironment => 'Creating virtual environment…',
    InstallStage.installingDependencies =>
      detail ?? 'Installing dependencies (~750 MB)…',
    InstallStage.copyingWorker => 'Preparing worker…',
    InstallStage.verifying => 'Verifying installation…',
    InstallStage.complete => 'Installation complete',
  };
}

/// Manages the app-controlled Python venv used by the demucs worker.
///
/// The venv lives at [venvDir] inside the app's models directory so it is
/// never placed in the user's global Python environment.
class RuntimeManager {
  final String modelsDir;
  final _log = AppLogger.get('RuntimeManager');

  RuntimeManager({required this.modelsDir});

  String get venvDir => p.join(modelsDir, 'venvs', 'demucs');

  String get pythonExe => Platform.isWindows
      ? p.join(venvDir, 'Scripts', 'python.exe')
      : p.join(venvDir, 'bin', 'python3');

  String get workerPath => p.join(modelsDir, 'workers', 'demucs_worker.py');

  // ── Public API ────────────────────────────────────────────────────────────

  Future<bool> isReady() async {
    if (!File(pythonExe).existsSync()) return false;
    if (!File(workerPath).existsSync()) return false;
    // Quick sanity: can the venv's python import demucs?
    try {
      final result = await Process.run(pythonExe, [
        '-c',
        'import demucs, torch',
      ], runInShell: false);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Stream<InstallProgress> install() async* {
    yield const InstallProgress(InstallStage.findingPython);
    final systemPython = await _findSystemPython();
    if (systemPython == null) {
      throw const DependencyException(
        'Python 3.10 or later was not found. '
        'Please install Python from python.org.',
        dependency: 'python3',
      );
    }
    _log.info('Using system Python: $systemPython');

    yield const InstallProgress(InstallStage.creatingEnvironment);
    await _createVenv(systemPython);

    yield const InstallProgress(InstallStage.installingDependencies);
    await for (final line in _pipInstall()) {
      yield InstallProgress(InstallStage.installingDependencies, detail: line);
    }

    yield const InstallProgress(InstallStage.copyingWorker);
    await _copyWorkerScript();

    yield const InstallProgress(InstallStage.verifying);
    await _verify();

    yield const InstallProgress(InstallStage.complete);
  }

  Future<void> uninstall() async {
    final venv = Directory(venvDir);
    if (venv.existsSync()) await venv.delete(recursive: true);
    final worker = File(workerPath);
    if (worker.existsSync()) await worker.delete();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static const _pythonCandidates = [
    'python3',
    'python',
    '/opt/homebrew/bin/python3',
    '/usr/local/bin/python3',
    '/usr/bin/python3',
    '/Library/Frameworks/Python.framework/Versions/Current/bin/python3',
    r'C:\Python312\python.exe',
    r'C:\Python311\python.exe',
    r'C:\Python310\python.exe',
  ];

  Future<String?> _findSystemPython() async {
    for (final candidate in _pythonCandidates) {
      try {
        final result = await Process.run(candidate, [
          '--version',
        ], runInShell: false);
        if (result.exitCode != 0) continue;
        final versionStr = (result.stdout as String).trim();
        final match = RegExp(r'Python 3\.(\d+)').firstMatch(versionStr);
        if (match != null && int.parse(match.group(1)!) >= 10) {
          return candidate;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _createVenv(String systemPython) async {
    final venv = Directory(venvDir);
    if (venv.existsSync()) {
      _log.info('Venv already exists; re-using: $venvDir');
      return;
    }
    await Directory(p.dirname(venvDir)).create(recursive: true);
    final result = await Process.run(systemPython, [
      '-m',
      'venv',
      venvDir,
    ], runInShell: false);
    if (result.exitCode != 0) {
      throw ProcessingException(
        'Failed to create Python virtual environment.',
        technicalDetails: result.stderr as String,
      );
    }
  }

  Stream<String> _pipInstall() async* {
    // Use pip from the venv.
    final pip = Platform.isWindows
        ? p.join(venvDir, 'Scripts', 'pip.exe')
        : p.join(venvDir, 'bin', 'pip');

    final process = await Process.start(pip, [
      'install',
      '--progress-bar',
      'off',
      'numpy',
      'demucs==4.1.0',
      'torchaudio',
      'torchcodec',
    ], runInShell: false);

    await for (final line
        in process.stdout
            .transform(const SystemEncoding().decoder)
            .transform(const LineSplitter())) {
      yield line;
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final err = await process.stderr
          .transform(const SystemEncoding().decoder)
          .join();
      throw ProcessingException(
        'Dependency installation failed.',
        technicalDetails: err,
      );
    }
  }

  Future<void> _copyWorkerScript() async {
    final workerDir = Directory(p.dirname(workerPath));
    await workerDir.create(recursive: true);

    // Load the bundled worker script from Flutter assets.
    final scriptContent = await rootBundle.loadString('tools/demucs_worker.py');
    await File(workerPath).writeAsString(scriptContent);
  }

  Future<void> _verify() async {
    final result = await Process.run(pythonExe, [
      '-c',
      'import demucs, torch, torchaudio; print("ok")',
    ], runInShell: false);
    if (result.exitCode != 0) {
      throw ProcessingException(
        'Installation verification failed.',
        technicalDetails: result.stderr as String,
      );
    }
    _log.info('Runtime verification passed.');
  }

  // ── Worker invocation helper ──────────────────────────────────────────────

  Future<Process> startWorker({required Map<String, dynamic> command}) async {
    if (!File(pythonExe).existsSync()) {
      throw const DependencyException(
        'Demucs runtime is not installed.',
        dependency: 'demucs',
      );
    }
    if (!File(workerPath).existsSync()) {
      await _copyWorkerScript();
    }

    final env = Map<String, String>.from(Platform.environment);
    // Keep model cache inside the app's managed directory.
    env['TORCH_HOME'] = p.join(modelsDir, 'torch_cache');
    // Ensure no interactive prompts.
    env['PYTHONDONTWRITEBYTECODE'] = '1';

    final process = await Process.start(
      pythonExe,
      [workerPath],
      runInShell: false,
      environment: env,
    );

    // Send command as a single JSON line to stdin, then close.
    process.stdin.writeln(jsonEncode(command));
    await process.stdin.close();

    return process;
  }
}
