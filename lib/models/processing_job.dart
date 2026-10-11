import 'package:equatable/equatable.dart';

enum ProcessingJobType {
  audioExtract,
  vocalSeparation,
  backgroundRemoval,
  mediaConvert,
}

enum ProcessingJobStatus { pending, processing, completed, failed, cancelled }

class ProcessingJob extends Equatable {
  final String id;
  final ProcessingJobType jobType;
  final String inputPath;
  final String? outputPath;
  final ProcessingJobStatus status;
  final double progress;
  final String? errorMessage;
  final Map<String, dynamic> params;
  final DateTime createdAt;
  final DateTime? completedAt;

  const ProcessingJob({
    required this.id,
    required this.jobType,
    required this.inputPath,
    this.outputPath,
    this.status = ProcessingJobStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.params = const {},
    required this.createdAt,
    this.completedAt,
  });

  ProcessingJob copyWith({
    String? id,
    ProcessingJobType? jobType,
    String? inputPath,
    String? outputPath,
    ProcessingJobStatus? status,
    double? progress,
    String? errorMessage,
    Map<String, dynamic>? params,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return ProcessingJob(
      id: id ?? this.id,
      jobType: jobType ?? this.jobType,
      inputPath: inputPath ?? this.inputPath,
      outputPath: outputPath ?? this.outputPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      params: params ?? this.params,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [id, jobType, status, progress];
}
