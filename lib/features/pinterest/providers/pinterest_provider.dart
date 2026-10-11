import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/download_task.dart' show DownloadType;
import '../../../models/media_info.dart';
import '../../../providers/app_providers.dart';

enum PinterestMetadataState { idle, loading, success, error }

class PinterestState {
  final PinterestMetadataState metadataState;
  final MediaInfo? mediaInfo;
  final String? errorMessage;
  final String? technicalError;
  final QualityOption selectedQuality;
  final bool isEnqueuing;

  const PinterestState({
    this.metadataState = PinterestMetadataState.idle,
    this.mediaInfo,
    this.errorMessage,
    this.technicalError,
    QualityOption? selectedQuality,
    this.isEnqueuing = false,
  }) : selectedQuality = selectedQuality ?? QualityOption.best;

  PinterestState copyWith({
    PinterestMetadataState? metadataState,
    MediaInfo? mediaInfo,
    String? errorMessage,
    String? technicalError,
    QualityOption? selectedQuality,
    bool? isEnqueuing,
    bool clearError = false,
    bool clearMedia = false,
  }) {
    return PinterestState(
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

class PinterestNotifier extends Notifier<PinterestState> {
  @override
  PinterestState build() => const PinterestState();

  Future<void> fetchMetadata(String url) async {
    if (url.trim().isEmpty) return;

    state = state.copyWith(
      metadataState: PinterestMetadataState.loading,
      clearError: true,
      clearMedia: true,
    );

    try {
      final info = await ref.read(metadataResolverProvider).resolve(url);
      state = state.copyWith(
        metadataState: PinterestMetadataState.success,
        mediaInfo: info,
        selectedQuality: QualityOption.best,
      );
    } on ValidationException catch (e) {
      state = state.copyWith(
        metadataState: PinterestMetadataState.error,
        errorMessage: e.message,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        metadataState: PinterestMetadataState.error,
        errorMessage: e.message,
        technicalError: e.technicalDetails,
      );
    } catch (e) {
      state = state.copyWith(
        metadataState: PinterestMetadataState.error,
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
    state = const PinterestState();
  }
}

final pinterestProvider = NotifierProvider<PinterestNotifier, PinterestState>(
  PinterestNotifier.new,
);
