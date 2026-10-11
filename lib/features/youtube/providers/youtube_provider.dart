import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/download_task.dart' show DownloadType;
import '../../../models/media_info.dart';
import '../../../providers/app_providers.dart';

enum MetadataState { idle, loading, success, error }

class YouTubeState {
  final MetadataState metadataState;
  final MediaInfo? mediaInfo;
  final String? errorMessage;
  final String? technicalError;
  final QualityOption selectedQuality;
  final bool isEnqueuing;

  const YouTubeState({
    this.metadataState = MetadataState.idle,
    this.mediaInfo,
    this.errorMessage,
    this.technicalError,
    QualityOption? selectedQuality,
    this.isEnqueuing = false,
  }) : selectedQuality = selectedQuality ?? QualityOption.best;

  YouTubeState copyWith({
    MetadataState? metadataState,
    MediaInfo? mediaInfo,
    String? errorMessage,
    String? technicalError,
    QualityOption? selectedQuality,
    bool? isEnqueuing,
    bool clearError = false,
    bool clearMedia = false,
  }) {
    return YouTubeState(
      metadataState: metadataState ?? this.metadataState,
      mediaInfo: clearMedia ? null : (mediaInfo ?? this.mediaInfo),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      technicalError: clearError
          ? null
          : (technicalError ?? this.technicalError),
      selectedQuality: selectedQuality ?? this.selectedQuality,
      isEnqueuing: isEnqueuing ?? this.isEnqueuing,
    );
  }
}

class YouTubeNotifier extends Notifier<YouTubeState> {
  @override
  YouTubeState build() => const YouTubeState();

  Future<void> fetchMetadata(String url) async {
    if (url.trim().isEmpty) return;

    state = state.copyWith(
      metadataState: MetadataState.loading,
      clearError: true,
      clearMedia: true,
    );

    try {
      final info = await ref.read(metadataResolverProvider).resolve(url);
      state = state.copyWith(
        metadataState: MetadataState.success,
        mediaInfo: info,
        // Auto-select best quality option
        selectedQuality: QualityOption.best,
      );
    } on ValidationException catch (e) {
      state = state.copyWith(
        metadataState: MetadataState.error,
        errorMessage: e.message,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        metadataState: MetadataState.error,
        errorMessage: e.message,
        technicalError: e.technicalDetails,
      );
    } catch (e) {
      state = state.copyWith(
        metadataState: MetadataState.error,
        errorMessage: 'Unable to retrieve media information.',
        technicalError: e.toString(),
      );
    }
  }

  void selectQuality(QualityOption option) {
    state = state.copyWith(selectedQuality: option);
  }

  Future<void> startDownload({required String outputDirectory}) async {
    final info = state.mediaInfo;
    if (info == null) return;

    state = state.copyWith(isEnqueuing: true);
    try {
      final quality = state.selectedQuality;
      final downloadType = quality.preset == QualityPreset.audioOnly
          ? DownloadType.audioOnly
          : DownloadType.videoAndAudio;

      await ref
          .read(downloadEngineProvider)
          .enqueue(
            url: info.url,
            formatSelector: quality.formatSelector,
            downloadType: downloadType,
            outputDirectory: outputDirectory,
            cachedMetadata: info,
          );
    } finally {
      state = state.copyWith(isEnqueuing: false);
    }
  }

  void reset() {
    state = const YouTubeState();
  }
}

final youTubeProvider = NotifierProvider<YouTubeNotifier, YouTubeState>(
  YouTubeNotifier.new,
);
