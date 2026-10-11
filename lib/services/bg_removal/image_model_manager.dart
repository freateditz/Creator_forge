import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/logging/app_logger.dart';
import '../../models/bg_removal_request.dart';
import 'bg_removal_progress_parser.dart';
import 'image_runtime_manager.dart';

enum ImageModelInstallStatus {
  unknown,
  checking,
  notInstalled,
  installing,
  installed,
  failed,
}

class ImageRuntimeInfo {
  final String rembgVersion;
  final String ortVersion;
  final List<String> providers;

  const ImageRuntimeInfo({
    required this.rembgVersion,
    required this.ortVersion,
    required this.providers,
  });

  bool get hasCoreML => providers.contains('CoreMLExecutionProvider');
  bool get hasCuda => providers.contains('CUDAExecutionProvider');

  String get acceleratorLabel {
    if (hasCoreML) return 'CoreML';
    if (hasCuda) return 'CUDA';
    return 'CPU';
  }
}

class ImageModelManagerState {
  final ImageModelInstallStatus status;
  final String? statusDetail;
  final ImageRuntimeInfo? runtimeInfo;
  final String? errorMessage;

  const ImageModelManagerState({
    this.status = ImageModelInstallStatus.unknown,
    this.statusDetail,
    this.runtimeInfo,
    this.errorMessage,
  });

  bool get isReady => status == ImageModelInstallStatus.installed;

  ImageModelManagerState copyWith({
    ImageModelInstallStatus? status,
    String? statusDetail,
    ImageRuntimeInfo? runtimeInfo,
    String? errorMessage,
    bool clearError = false,
    bool clearDetail = false,
  }) => ImageModelManagerState(
    status: status ?? this.status,
    statusDetail: clearDetail ? null : (statusDetail ?? this.statusDetail),
    runtimeInfo: runtimeInfo ?? this.runtimeInfo,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// Manages installation of the bg_removal runtime and model weights.
class ImageModelManager {
  final ImageRuntimeManager _runtime;
  final _log = AppLogger.get('ImageModelManager');
  final _parser = BgRemovalProgressParser();

  final _stateController = StreamController<ImageModelManagerState>.broadcast();

  Stream<ImageModelManagerState> get stateStream => _stateController.stream;
  ImageModelManagerState _state = const ImageModelManagerState();
  ImageModelManagerState get state => _state;

  ImageModelManager({required this._runtime});

  void _emit(ImageModelManagerState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  Future<void> checkStatus() async {
    _emit(
      _state.copyWith(
        status: ImageModelInstallStatus.checking,
        clearError: true,
      ),
    );
    final ready = await _runtime.isReady();
    if (!ready) {
      _emit(
        _state.copyWith(
          status: ImageModelInstallStatus.notInstalled,
          clearDetail: true,
        ),
      );
      return;
    }

    final info = await _checkRuntime(BgRemovalModel.isnetGeneralUse.id);
    if (info == null || !info.modelCached) {
      _emit(
        _state.copyWith(
          status: ImageModelInstallStatus.notInstalled,
          clearDetail: true,
        ),
      );
      return;
    }

    _emit(
      _state.copyWith(
        status: ImageModelInstallStatus.installed,
        runtimeInfo: ImageRuntimeInfo(
          rembgVersion: info.rembgVersion,
          ortVersion: info.ortVersion,
          providers: info.providers,
        ),
        clearDetail: true,
        clearError: true,
      ),
    );
  }

  Future<void> install({
    BgRemovalModel model = BgRemovalModel.isnetGeneralUse,
  }) async {
    if (_state.status == ImageModelInstallStatus.installing) return;

    _emit(
      _state.copyWith(
        status: ImageModelInstallStatus.installing,
        clearError: true,
      ),
    );

    try {
      await for (final progress in _runtime.install()) {
        _emit(_state.copyWith(statusDetail: progress.label));
      }

      _emit(
        _state.copyWith(
          statusDetail:
              'Downloading ${model.displayName} model '
              '(${model.sizeLabel})…',
        ),
      );
      await _downloadModel(model.id);

      final info = await _checkRuntime(model.id);
      _emit(
        _state.copyWith(
          status: ImageModelInstallStatus.installed,
          runtimeInfo: info != null
              ? ImageRuntimeInfo(
                  rembgVersion: info.rembgVersion,
                  ortVersion: info.ortVersion,
                  providers: info.providers,
                )
              : null,
          clearDetail: true,
          clearError: true,
        ),
      );
    } catch (e) {
      _log.warning('BG removal installation failed.', e);
      _emit(
        _state.copyWith(
          status: ImageModelInstallStatus.failed,
          errorMessage: e.toString(),
          clearDetail: true,
        ),
      );
    }
  }

  Future<void> uninstall() async {
    await _runtime.uninstall();
    _emit(
      const ImageModelManagerState(
        status: ImageModelInstallStatus.notInstalled,
      ),
    );
  }

  bool isModelCached(BgRemovalModel model) {
    final home = _runtime.rembgModelsDir;
    final modelFile = p.join(home, 'models', model.id, '${model.id}.onnx');
    return File(modelFile).existsSync();
  }

  void dispose() => _stateController.close();

  // ── Private ──────────────────────────────────────────────────────────────

  Future<BgRuntimeInfoEvent?> _checkRuntime(String modelId) async {
    try {
      final process = await _runtime.startWorker(
        command: {'action': 'check_runtime', 'model_name': modelId},
      );

      BgRuntimeInfoEvent? info;
      await for (final line
          in process.stdout
              .transform(const SystemEncoding().decoder)
              .transform(const LineSplitter())) {
        final event = _parser.parseLine(line);
        if (event is BgRuntimeInfoEvent) info = event;
      }
      await process.exitCode;
      return info;
    } catch (e) {
      _log.warning('Runtime check failed: $e');
      return null;
    }
  }

  Future<void> _downloadModel(String modelId) async {
    if (isModelCached(BgRemovalModel.fromId(modelId))) {
      _log.info('Model $modelId already cached, skipping download.');
      return;
    }

    final process = await _runtime.startWorker(
      command: {'action': 'download_model', 'model_name': modelId},
    );

    String? errorMessage;
    await for (final line
        in process.stdout
            .transform(const SystemEncoding().decoder)
            .transform(const LineSplitter())) {
      final event = _parser.parseLine(line);
      if (event is BgErrorEvent) errorMessage = event.message;
    }

    final code = await process.exitCode;
    if (code != 0) {
      throw Exception(errorMessage ?? 'Model download failed (exit $code)');
    }
  }
}
