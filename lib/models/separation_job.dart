import 'processing_job.dart';
import 'separation_request.dart';

/// Granular lifecycle stage for a separation job.
enum SeparationStage {
  pending,
  preparingAudio,
  loadingModel,
  separating,
  exportingStems,
  verifyingOutput,
  completed,
  failed,
  cancelling,
  cancelled;

  /// Maps to the coarse DB status.
  ProcessingJobStatus get dbStatus => switch (this) {
    SeparationStage.pending => ProcessingJobStatus.pending,
    SeparationStage.completed => ProcessingJobStatus.completed,
    SeparationStage.failed => ProcessingJobStatus.failed,
    SeparationStage.cancelled ||
    SeparationStage.cancelling => ProcessingJobStatus.cancelled,
    _ => ProcessingJobStatus.processing,
  };

  bool get isTerminal =>
      this == SeparationStage.completed ||
      this == SeparationStage.failed ||
      this == SeparationStage.cancelled;

  bool get isActive =>
      this == SeparationStage.preparingAudio ||
      this == SeparationStage.loadingModel ||
      this == SeparationStage.separating ||
      this == SeparationStage.exportingStems ||
      this == SeparationStage.verifyingOutput;

  String get label => switch (this) {
    SeparationStage.pending => 'Pending',
    SeparationStage.preparingAudio => 'Preparing audio…',
    SeparationStage.loadingModel => 'Loading model…',
    SeparationStage.separating => 'Separating…',
    SeparationStage.exportingStems => 'Exporting stems…',
    SeparationStage.verifyingOutput => 'Verifying…',
    SeparationStage.completed => 'Completed',
    SeparationStage.failed => 'Failed',
    SeparationStage.cancelling => 'Cancelling…',
    SeparationStage.cancelled => 'Cancelled',
  };
}

/// In-memory representation of one separation job including live progress.
class SeparationJob {
  final String id;
  final String inputPath;
  final SeparationRequest request;
  final SeparationStage stage;

  /// [0.0, 1.0] during separating stage; null otherwise.
  final double? progress;

  /// Resolved device actually used (e.g. 'mps', 'cpu').
  final String? resolvedDevice;

  /// Output paths keyed by stem name. Non-null when stage is completed.
  final Map<String, String>? outputStems;

  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  const SeparationJob({
    required this.id,
    required this.inputPath,
    required this.request,
    this.stage = SeparationStage.pending,
    this.progress,
    this.resolvedDevice,
    this.outputStems,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  bool get isTerminal => stage.isTerminal;
  bool get isActive => stage.isActive;

  SeparationJob copyWith({
    SeparationStage? stage,
    double? progress,
    String? resolvedDevice,
    Map<String, String>? outputStems,
    String? errorMessage,
    DateTime? completedAt,
    bool clearProgress = false,
    bool clearError = false,
  }) {
    return SeparationJob(
      id: id,
      inputPath: inputPath,
      request: request,
      stage: stage ?? this.stage,
      progress: clearProgress ? null : (progress ?? this.progress),
      resolvedDevice: resolvedDevice ?? this.resolvedDevice,
      outputStems: outputStems ?? this.outputStems,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
