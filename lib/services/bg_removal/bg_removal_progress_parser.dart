import 'dart:convert';

/// Typed events emitted by the bg_removal_worker process.
sealed class BgWorkerEvent {
  const BgWorkerEvent();
}

class BgStageEvent extends BgWorkerEvent {
  final String stage;
  final String? model;

  const BgStageEvent(this.stage, {this.model});

  @override
  String toString() => 'BgStageEvent($stage)';
}

class BgImageInfoEvent extends BgWorkerEvent {
  final int width;
  final int height;
  final String mode;
  final bool hasExistingAlpha;

  const BgImageInfoEvent({
    required this.width,
    required this.height,
    required this.mode,
    required this.hasExistingAlpha,
  });
}

class BgRuntimeInfoEvent extends BgWorkerEvent {
  final String rembgVersion;
  final String ortVersion;
  final String modelName;
  final bool modelCached;
  final List<String> providers;

  const BgRuntimeInfoEvent({
    required this.rembgVersion,
    required this.ortVersion,
    required this.modelName,
    required this.modelCached,
    required this.providers,
  });

  bool get hasCoreML => providers.contains('CoreMLExecutionProvider');
  bool get hasCuda => providers.contains('CUDAExecutionProvider');
}

class BgCompleteEvent extends BgWorkerEvent {
  final String? outputPath;
  final int? width;
  final int? height;
  final bool hasAlpha;
  final int? fileSize;

  /// Populated for download_model completions.
  final String? model;

  const BgCompleteEvent({
    this.outputPath,
    this.width,
    this.height,
    this.hasAlpha = false,
    this.fileSize,
    this.model,
  });
}

class BgErrorEvent extends BgWorkerEvent {
  final String message;
  final String? tracebackText;

  const BgErrorEvent(this.message, {this.tracebackText});

  @override
  String toString() => 'BgErrorEvent($message)';
}

class BgInfoEvent extends BgWorkerEvent {
  final String message;

  const BgInfoEvent(this.message);
}

class BgUnknownEvent extends BgWorkerEvent {
  final Map<String, dynamic> raw;

  const BgUnknownEvent(this.raw);
}

/// Parses JSON lines produced by the bg_removal_worker on stdout.
class BgRemovalProgressParser {
  /// Returns null if [line] is blank or cannot be parsed as JSON.
  BgWorkerEvent? parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) return null;
      map = decoded;
    } catch (_) {
      return null;
    }

    final type = map['type'] as String?;
    return switch (type) {
      'stage' => BgStageEvent(
        map['stage'] as String? ?? '',
        model: map['model'] as String?,
      ),
      'image_info' => BgImageInfoEvent(
        width: map['width'] as int? ?? 0,
        height: map['height'] as int? ?? 0,
        mode: map['mode'] as String? ?? '',
        hasExistingAlpha: map['has_existing_alpha'] as bool? ?? false,
      ),
      'runtime_info' => BgRuntimeInfoEvent(
        rembgVersion: map['rembg_version'] as String? ?? '',
        ortVersion: map['ort_version'] as String? ?? '',
        modelName: map['model_name'] as String? ?? '',
        modelCached: map['model_cached'] as bool? ?? false,
        providers: _parseStringList(map['providers']),
      ),
      'complete' => BgCompleteEvent(
        outputPath: map['output_path'] as String?,
        width: map['width'] as int?,
        height: map['height'] as int?,
        hasAlpha: map['has_alpha'] as bool? ?? false,
        fileSize: map['file_size'] as int?,
        model: map['model'] as String?,
      ),
      'error' => BgErrorEvent(
        map['message'] as String? ?? 'Unknown error',
        tracebackText: map['traceback'] as String?,
      ),
      'info' => BgInfoEvent(map['message'] as String? ?? ''),
      _ => BgUnknownEvent(map),
    };
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is String) item,
    ];
  }
}
