import 'processing_job.dart';
import 'bg_removal_request.dart';

enum BgRemovalStage {
  pending,
  analyzingImage,
  loadingModel,
  generatingMask,
  refiningEdges,
  exporting,
  verifyingOutput,
  completed,
  failed,
  cancelling,
  cancelled;

  ProcessingJobStatus get dbStatus => switch (this) {
    BgRemovalStage.pending => ProcessingJobStatus.pending,
    BgRemovalStage.completed => ProcessingJobStatus.completed,
    BgRemovalStage.failed => ProcessingJobStatus.failed,
    BgRemovalStage.cancelled ||
    BgRemovalStage.cancelling => ProcessingJobStatus.cancelled,
    _ => ProcessingJobStatus.processing,
  };

  bool get isTerminal =>
      this == BgRemovalStage.completed ||
      this == BgRemovalStage.failed ||
      this == BgRemovalStage.cancelled;

  bool get isActive =>
      this == BgRemovalStage.analyzingImage ||
      this == BgRemovalStage.loadingModel ||
      this == BgRemovalStage.generatingMask ||
      this == BgRemovalStage.refiningEdges ||
      this == BgRemovalStage.exporting ||
      this == BgRemovalStage.verifyingOutput;

  String get label => switch (this) {
    BgRemovalStage.pending => 'Pending',
    BgRemovalStage.analyzingImage => 'Analyzing image…',
    BgRemovalStage.loadingModel => 'Loading model…',
    BgRemovalStage.generatingMask => 'Generating mask…',
    BgRemovalStage.refiningEdges => 'Refining edges…',
    BgRemovalStage.exporting => 'Exporting PNG…',
    BgRemovalStage.verifyingOutput => 'Verifying…',
    BgRemovalStage.completed => 'Completed',
    BgRemovalStage.failed => 'Failed',
    BgRemovalStage.cancelling => 'Cancelling…',
    BgRemovalStage.cancelled => 'Cancelled',
  };
}

class BgRemovalJob {
  final String id;
  final String inputPath;
  final BgRemovalRequest request;
  final BgRemovalStage stage;
  final String? outputPath;
  final String? errorMessage;
  final int? outputWidth;
  final int? outputHeight;
  final int? outputFileSize;
  final DateTime createdAt;
  final DateTime? completedAt;

  const BgRemovalJob({
    required this.id,
    required this.inputPath,
    required this.request,
    this.stage = BgRemovalStage.pending,
    this.outputPath,
    this.errorMessage,
    this.outputWidth,
    this.outputHeight,
    this.outputFileSize,
    required this.createdAt,
    this.completedAt,
  });

  bool get isTerminal => stage.isTerminal;
  bool get isActive => stage.isActive;

  BgRemovalJob copyWith({
    BgRemovalStage? stage,
    String? outputPath,
    String? errorMessage,
    int? outputWidth,
    int? outputHeight,
    int? outputFileSize,
    DateTime? completedAt,
    bool clearError = false,
  }) => BgRemovalJob(
    id: id,
    inputPath: inputPath,
    request: request,
    stage: stage ?? this.stage,
    outputPath: outputPath ?? this.outputPath,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    outputWidth: outputWidth ?? this.outputWidth,
    outputHeight: outputHeight ?? this.outputHeight,
    outputFileSize: outputFileSize ?? this.outputFileSize,
    createdAt: createdAt,
    completedAt: completedAt ?? this.completedAt,
  );
}
