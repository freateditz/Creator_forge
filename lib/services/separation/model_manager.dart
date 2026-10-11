import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/logging/app_logger.dart';
import 'demucs_progress_parser.dart';
import 'hardware_capability_service.dart';
import 'runtime_manager.dart';

enum ModelInstallStatus {
  unknown,
  checking,
  notInstalled,
  installing,
  installed,
  failed,
}

class ModelManagerState {
  final ModelInstallStatus status;
  final String? statusDetail;
  final HardwareInfo? hardwareInfo;
  final String? errorMessage;

  const ModelManagerState({
    this.status = ModelInstallStatus.unknown,
    this.statusDetail,
    this.hardwareInfo,
    this.errorMessage,
  });

  bool get isReady =>
      status == ModelInstallStatus.installed && hardwareInfo != null;

  ModelManagerState copyWith({
    ModelInstallStatus? status,
    String? statusDetail,
    HardwareInfo? hardwareInfo,
    String? errorMessage,
    bool clearError = false,
    bool clearDetail = false,
  }) {
    return ModelManagerState(
      status: status ?? this.status,
      statusDetail: clearDetail ? null : (statusDetail ?? this.statusDetail),
      hardwareInfo: hardwareInfo ?? this.hardwareInfo,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Manages installation of the demucs runtime and model weights.
class ModelManager {
  final RuntimeManager _runtime;
  final HardwareCapabilityService _hw;
  final _log = AppLogger.get('ModelManager');
  final _parser = DemucsProgressParser();

  final _stateController = StreamController<ModelManagerState>.broadcast();

  Stream<ModelManagerState> get stateStream => _stateController.stream;
  ModelManagerState _state = const ModelManagerState();
  ModelManagerState get state => _state;

  ModelManager({required this._runtime, required this._hw});

  void _emit(ModelManagerState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  Future<void> checkStatus() async {
    _emit(
      _state.copyWith(status: ModelInstallStatus.checking, clearError: true),
    );
    final ready = await _runtime.isReady();
    if (!ready) {
      _emit(
        _state.copyWith(
          status: ModelInstallStatus.notInstalled,
          clearDetail: true,
        ),
      );
      return;
    }
    final hw = await _hw.check();
    _emit(
      _state.copyWith(
        status: ModelInstallStatus.installed,
        hardwareInfo: hw,
        clearDetail: true,
        clearError: true,
      ),
    );
  }

  Future<void> install() async {
    if (_state.status == ModelInstallStatus.installing) return;

    _emit(
      _state.copyWith(status: ModelInstallStatus.installing, clearError: true),
    );

    try {
      await for (final progress in _runtime.install()) {
        _emit(_state.copyWith(statusDetail: progress.label));
      }

      // Download model weights via worker
      _emit(
        _state.copyWith(statusDetail: 'Downloading htdemucs model (~83 MB)…'),
      );
      await _downloadModel();

      final hw = await _hw.check();
      _emit(
        _state.copyWith(
          status: ModelInstallStatus.installed,
          hardwareInfo: hw,
          clearDetail: true,
          clearError: true,
        ),
      );
    } catch (e) {
      _log.warning('Installation failed.', e);
      _emit(
        _state.copyWith(
          status: ModelInstallStatus.failed,
          errorMessage: e.toString(),
          clearDetail: true,
        ),
      );
    }
  }

  Future<void> uninstall() async {
    await _runtime.uninstall();
    _emit(const ModelManagerState(status: ModelInstallStatus.notInstalled));
  }

  Future<bool> isModelCached(String modelName) async {
    // torch hub stores models under TORCH_HOME/hub/checkpoints/
    final torchHome = p.join(_runtime.modelsDir, 'torch_cache');
    final checkpointsDir = Directory(p.join(torchHome, 'hub', 'checkpoints'));
    if (!checkpointsDir.existsSync()) return false;
    // Any file that starts with the model name is sufficient.
    return checkpointsDir.listSync().whereType<File>().any(
      (f) => p.basename(f.path).startsWith(modelName),
    );
  }

  void dispose() => _stateController.close();

  // ── Private ──────────────────────────────────────────────────────────────

  Future<void> _downloadModel({String modelName = 'htdemucs'}) async {
    if (await isModelCached(modelName)) {
      _log.info('Model $modelName already cached, skipping download.');
      return;
    }

    final process = await _runtime.startWorker(
      command: {'action': 'download_model', 'model_name': modelName},
    );

    String? errorMessage;
    await for (final line
        in process.stdout
            .transform(const SystemEncoding().decoder)
            .transform(const LineSplitter())) {
      final event = _parser.parseLine(line);
      if (event is ErrorEvent) errorMessage = event.message;
    }

    final code = await process.exitCode;
    if (code != 0) {
      throw Exception(errorMessage ?? 'Model download failed (exit $code)');
    }
  }
}
