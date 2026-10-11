import 'dart:convert';

/// Typed events emitted by the demucs worker process.
sealed class WorkerEvent {
  const WorkerEvent();
}

class StageEvent extends WorkerEvent {
  final String stage;
  final String? model;
  final String? device;

  const StageEvent(this.stage, {this.model, this.device});

  @override
  String toString() => 'StageEvent($stage)';
}

class ProgressEvent extends WorkerEvent {
  final String stage;

  /// [0.0, 100.0]
  final double percent;

  const ProgressEvent(this.stage, this.percent);

  @override
  String toString() => 'ProgressEvent($stage, ${percent.toStringAsFixed(1)}%)';
}

class RuntimeInfoEvent extends WorkerEvent {
  final String demucsVersion;
  final String torchVersion;
  final bool mpsAvailable;
  final bool cudaAvailable;
  final int cudaDeviceCount;

  const RuntimeInfoEvent({
    required this.demucsVersion,
    required this.torchVersion,
    required this.mpsAvailable,
    required this.cudaAvailable,
    required this.cudaDeviceCount,
  });
}

class CompleteEvent extends WorkerEvent {
  /// Stem name → absolute output path.
  final Map<String, String> stems;

  /// Populated for download_model completions.
  final String? model;

  const CompleteEvent({this.stems = const {}, this.model});

  @override
  String toString() => 'CompleteEvent(stems=${stems.keys.toList()})';
}

class ErrorEvent extends WorkerEvent {
  final String message;
  final String? tracebackText;

  const ErrorEvent(this.message, {this.tracebackText});

  @override
  String toString() => 'ErrorEvent($message)';
}

class InfoEvent extends WorkerEvent {
  final String message;

  const InfoEvent(this.message);
}

class UnknownEvent extends WorkerEvent {
  final Map<String, dynamic> raw;

  const UnknownEvent(this.raw);
}

/// Parses JSON lines produced by the demucs worker on stdout.
class DemucsProgressParser {
  /// Returns null if [line] is blank or cannot be parsed as JSON.
  WorkerEvent? parseLine(String line) {
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
      'stage' => StageEvent(
        map['stage'] as String? ?? '',
        model: map['model'] as String?,
        device: map['device'] as String?,
      ),
      'progress' => ProgressEvent(
        map['stage'] as String? ?? 'separating',
        (map['percent'] as num?)?.toDouble() ?? 0.0,
      ),
      'runtime_info' => RuntimeInfoEvent(
        demucsVersion: map['demucs_version'] as String? ?? '',
        torchVersion: map['torch_version'] as String? ?? '',
        mpsAvailable: map['mps_available'] as bool? ?? false,
        cudaAvailable: map['cuda_available'] as bool? ?? false,
        cudaDeviceCount: map['cuda_device_count'] as int? ?? 0,
      ),
      'complete' => CompleteEvent(
        stems: _parseStems(map['stems']),
        model: map['model'] as String?,
      ),
      'error' => ErrorEvent(
        map['message'] as String? ?? 'Unknown error',
        tracebackText: map['traceback'] as String?,
      ),
      'info' => InfoEvent(map['message'] as String? ?? ''),
      _ => UnknownEvent(map),
    };
  }

  static Map<String, String> _parseStems(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    };
  }
}
