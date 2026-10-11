import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../database/app_database.dart';
import '../models/app_settings.dart';
import '../models/bg_removal_job.dart';
import '../models/download_task.dart';
import '../models/separation_job.dart';
import '../repositories/download_history_repository.dart';
import '../repositories/processing_job_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/audio/audio_processing_engine.dart';
import '../services/bg_removal/bg_removal_engine.dart';
import '../services/bg_removal/image_model_manager.dart';
import '../services/bg_removal/image_runtime_manager.dart';
import '../services/browser_extension/browser_request_handler.dart';
import '../services/browser_extension/ipc_server.dart';
import '../services/download/metadata_resolver.dart';
import '../services/download/segmented_http_engine.dart';
import '../services/download/ytdlp_download_engine.dart';
import '../services/download/ytdlp_locator.dart';
import '../services/ffmpeg/ffmpeg_service.dart';
import '../services/separation/hardware_capability_service.dart';
import '../services/separation/model_manager.dart';
import '../services/separation/runtime_manager.dart';
import '../services/separation/separation_engine.dart';
import '../services/provisioning/dependency_provisioner.dart';
import '../services/storage/storage_service.dart';

// ── Core infrastructure ─────────────────────────────────────────────────────

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

final downloadHistoryRepositoryProvider = Provider<DownloadHistoryRepository>((
  ref,
) {
  return DownloadHistoryRepository(ref.watch(appDatabaseProvider));
});

final ffmpegServiceProvider = Provider<FfmpegService>((ref) {
  return FfmpegServiceImpl();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final metadataResolverProvider = Provider<MetadataResolver>((ref) {
  return MetadataResolver();
});

// ── Settings ────────────────────────────────────────────────────────────────

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(() {
      return AppSettingsNotifier();
    });

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    return ref.watch(settingsRepositoryProvider).load();
  }

  Future<void> save(AppSettings Function(AppSettings) updater) async {
    final current = await future;
    final updated = updater(current);
    state = AsyncData(updated);
    await ref.read(settingsRepositoryProvider).save(updated);

    // Propagate relevant settings to download engine
    ref.read(downloadEngineProvider).maxConcurrent =
        updated.maxConcurrentDownloads;
    ref.read(downloadEngineProvider).defaultOutputDir =
        updated.defaultDownloadsDir;
  }
}

// ── Download engine ─────────────────────────────────────────────────────────

final downloadEngineProvider = Provider<YtDlpDownloadEngine>((ref) {
  final engine = YtDlpDownloadEngine(
    historyRepo: ref.watch(downloadHistoryRepositoryProvider),
    ffmpegService: ref.watch(ffmpegServiceProvider),
  );

  // Restore any tasks that were in-flight when the app last exited.
  engine.initialize().ignore();

  // Keep settings in sync after initial load
  ref.listen(appSettingsProvider, (_, next) {
    next.whenData((settings) {
      engine.maxConcurrent = settings.maxConcurrentDownloads;
      engine.defaultOutputDir = settings.defaultDownloadsDir;
    });
  });

  ref.onDispose(() => engine.dispose().ignore());
  return engine;
});

final downloadTasksProvider = StreamProvider<List<DownloadTask>>((ref) {
  return ref.watch(downloadEngineProvider).tasksStream;
});

// ── Segmented HTTP engine ─────────────────────────────────────────────────────

final segmentedEngineProvider = Provider<SegmentedHttpEngine>((ref) {
  final engine = SegmentedHttpEngine(
    historyRepo: ref.watch(downloadHistoryRepositoryProvider),
  );

  engine.initialize().ignore();

  ref.listen(appSettingsProvider, (_, next) {
    next.whenData((settings) {
      engine.maxConcurrent = settings.maxConcurrentDownloads;
      engine.segmentCount = settings.httpSegments;
      engine.defaultOutputDir = settings.defaultDownloadsDir;
    });
  });

  ref.onDispose(() => engine.dispose().ignore());
  return engine;
});

final segmentedTasksProvider = StreamProvider<List<DownloadTask>>((ref) {
  return ref.watch(segmentedEngineProvider).tasksStream;
});

// ── Audio processing ─────────────────────────────────────────────────────────

final processingJobRepositoryProvider = Provider<ProcessingJobRepository>((
  ref,
) {
  return ProcessingJobRepository(ref.watch(appDatabaseProvider));
});

final audioEngineProvider = Provider<AudioProcessingEngine>((ref) {
  final engine = AudioProcessingEngine(
    jobRepo: ref.watch(processingJobRepositoryProvider),
    ffmpegService: ref.watch(ffmpegServiceProvider),
  );
  engine.initialize().ignore();
  ref.onDispose(() => engine.dispose().ignore());
  return engine;
});

final audioJobsProvider = StreamProvider<List<AudioJob>>((ref) {
  return ref.watch(audioEngineProvider).jobsStream;
});

// ── Vocal separation ─────────────────────────────────────────────────────────

final runtimeManagerProvider = Provider<RuntimeManager>((ref) {
  return RuntimeManager(modelsDir: AppConfig.instance.modelsDir);
});

final modelManagerProvider = Provider<ModelManager>((ref) {
  final mgr = ModelManager(
    runtime: ref.watch(runtimeManagerProvider),
    hw: HardwareCapabilityService(ref.watch(runtimeManagerProvider)),
  );
  mgr.checkStatus().ignore();
  ref.onDispose(mgr.dispose);
  return mgr;
});

final modelManagerStateProvider = StreamProvider<ModelManagerState>((ref) {
  return ref.watch(modelManagerProvider).stateStream;
});

final separationEngineProvider = Provider<SeparationEngine>((ref) {
  final engine = SeparationEngine(
    jobRepo: ref.watch(processingJobRepositoryProvider),
    ffmpegService: ref.watch(ffmpegServiceProvider),
    runtime: ref.watch(runtimeManagerProvider),
  );
  engine.initialize().ignore();
  ref.onDispose(() => engine.dispose().ignore());
  return engine;
});

final separationJobsProvider = StreamProvider<List<SeparationJob>>((ref) {
  return ref.watch(separationEngineProvider).jobsStream;
});

// ── Background removal ───────────────────────────────────────────────────────

final imageRuntimeManagerProvider = Provider<ImageRuntimeManager>((ref) {
  return ImageRuntimeManager(modelsDir: AppConfig.instance.modelsDir);
});

final imageModelManagerProvider = Provider<ImageModelManager>((ref) {
  final mgr = ImageModelManager(
    runtime: ref.watch(imageRuntimeManagerProvider),
  );
  mgr.checkStatus().ignore();
  ref.onDispose(mgr.dispose);
  return mgr;
});

final imageModelManagerStateProvider = StreamProvider<ImageModelManagerState>((
  ref,
) {
  return ref.watch(imageModelManagerProvider).stateStream;
});

final bgRemovalEngineProvider = Provider<BgRemovalEngine>((ref) {
  final engine = BgRemovalEngine(
    jobRepo: ref.watch(processingJobRepositoryProvider),
    runtime: ref.watch(imageRuntimeManagerProvider),
  );
  engine.initialize().ignore();
  ref.onDispose(() => engine.dispose().ignore());
  return engine;
});

final bgRemovalJobsProvider = StreamProvider<List<BgRemovalJob>>((ref) {
  return ref.watch(bgRemovalEngineProvider).jobsStream;
});

// ── Browser extension IPC ────────────────────────────────────────────────────

/// Tracks task IDs that were initiated via the browser extension.
final browserTaskIdsProvider =
    StateNotifierProvider<_BrowserTaskIdsNotifier, Set<String>>(
      (_) => _BrowserTaskIdsNotifier(),
    );

class _BrowserTaskIdsNotifier extends StateNotifier<Set<String>> {
  _BrowserTaskIdsNotifier() : super({});
  void add(String id) => state = {...state, id};
}

final browserRequestHandlerProvider = Provider<BrowserRequestHandler>((ref) {
  return BrowserRequestHandler(
    downloadEngine: ref.watch(downloadEngineProvider),
    segmentedEngine: ref.watch(segmentedEngineProvider),
    metadataResolver: ref.watch(metadataResolverProvider),
    onTaskEnqueued: (id) => ref.read(browserTaskIdsProvider.notifier).add(id),
  );
});

final ipcServerProvider = Provider<IpcServer>((ref) {
  final server = IpcServer(ref.watch(browserRequestHandlerProvider));
  server.start().ignore();
  ref.onDispose(() => server.dispose().ignore());
  return server;
});

// ── Dependency checks ────────────────────────────────────────────────────────

final ffmpegAvailableProvider = FutureProvider<bool>((ref) async {
  return ref.watch(ffmpegServiceProvider).isAvailable();
});

final ffmpegVersionProvider = FutureProvider<String?>((ref) async {
  return ref.watch(ffmpegServiceProvider).getVersion();
});

final ytdlpAvailableProvider = FutureProvider<bool>((ref) async {
  return YtDlpLocator.instance.isAvailable();
});

final ytdlpVersionProvider = FutureProvider<String?>((ref) async {
  return YtDlpLocator.instance.getVersion();
});

// ── Dependency provisioning ──────────────────────────────────────────────────

final dependencyProvisionerProvider = Provider<DependencyProvisioner>((ref) {
  return DependencyProvisioner(binDir: AppConfig.instance.binDir);
});

enum ProvisioningStatus { idle, downloading, done, error }

class ProvisioningState {
  final ProvisioningStatus status;
  final double progress;
  final String? errorMessage;

  const ProvisioningState({
    this.status = ProvisioningStatus.idle,
    this.progress = 0,
    this.errorMessage,
  });

  ProvisioningState copyWith({
    ProvisioningStatus? status,
    double? progress,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProvisioningState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class YtDlpProvisioningNotifier extends Notifier<ProvisioningState> {
  @override
  ProvisioningState build() => const ProvisioningState();

  Future<void> provision() async {
    state = const ProvisioningState(status: ProvisioningStatus.downloading);
    try {
      await ref
          .read(dependencyProvisionerProvider)
          .provisionYtDlp(
            onProgress: (p) => state = state.copyWith(
              status: ProvisioningStatus.downloading,
              progress: p,
            ),
          );
      YtDlpLocator.instance.invalidate();
      ref.invalidate(ytdlpAvailableProvider);
      ref.invalidate(ytdlpVersionProvider);
      state = const ProvisioningState(
        status: ProvisioningStatus.done,
        progress: 1,
      );
    } catch (e) {
      state = ProvisioningState(
        status: ProvisioningStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() => state = const ProvisioningState();
}

final ytdlpProvisioningProvider =
    NotifierProvider<YtDlpProvisioningNotifier, ProvisioningState>(
      YtDlpProvisioningNotifier.new,
    );

class FfmpegProvisioningNotifier extends Notifier<ProvisioningState> {
  @override
  ProvisioningState build() => const ProvisioningState();

  Future<void> provision() async {
    state = const ProvisioningState(status: ProvisioningStatus.downloading);
    try {
      await ref
          .read(dependencyProvisionerProvider)
          .provisionFfmpeg(
            onProgress: (p) => state = state.copyWith(
              status: ProvisioningStatus.downloading,
              progress: p,
            ),
          );
      (ref.read(ffmpegServiceProvider) as FfmpegServiceImpl).invalidate();
      ref.invalidate(ffmpegAvailableProvider);
      ref.invalidate(ffmpegVersionProvider);
      state = const ProvisioningState(
        status: ProvisioningStatus.done,
        progress: 1,
      );
    } catch (e) {
      state = ProvisioningState(
        status: ProvisioningStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() => state = const ProvisioningState();
}

final ffmpegProvisioningProvider =
    NotifierProvider<FfmpegProvisioningNotifier, ProvisioningState>(
      FfmpegProvisioningNotifier.new,
    );
