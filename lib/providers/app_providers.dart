import 'dart:async';
import 'dart:io';

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
import '../services/browser_extension/native_host_service.dart';
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

final nativeHostServiceProvider = Provider<NativeHostService>((ref) {
  return NativeHostService();
});

/// Total bytes used by the downloads directory. Refreshes once per load.
final downloadsDirSizeProvider = FutureProvider.autoDispose<int>((ref) async {
  final storage = ref.read(storageServiceProvider);
  final settings = ref.watch(appSettingsProvider).valueOrNull;
  if (settings == null) return 0;
  return storage.getDirectorySize(settings.defaultDownloadsDir);
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

/// Unified stream that merges tasks from both download engines (yt-dlp + segmented HTTP).
/// Provides a single source of truth for the Downloads page UI.
final unifiedDownloadTasksProvider = StreamProvider<List<DownloadTask>>((ref) {
  final ytDlpStream = ref.watch(downloadEngineProvider).tasksStream;
  final segmentedStream = ref.watch(segmentedEngineProvider).tasksStream;

  return _mergeTaskStreams(ytDlpStream, segmentedStream);
});

Stream<List<DownloadTask>> _mergeTaskStreams(
  Stream<List<DownloadTask>> stream1,
  Stream<List<DownloadTask>> stream2,
) async* {
  List<DownloadTask> latest1 = [];
  List<DownloadTask> latest2 = [];

  final controller = StreamController<List<DownloadTask>>.broadcast();

  final sub1 = stream1.listen(
    (tasks) {
      latest1 = tasks;
      _emitMerged(controller, latest1, latest2);
    },
    onError: controller.addError,
    onDone: () => _emitMerged(controller, latest1, latest2),
  );

  final sub2 = stream2.listen(
    (tasks) {
      latest2 = tasks;
      _emitMerged(controller, latest1, latest2);
    },
    onError: controller.addError,
    onDone: () => _emitMerged(controller, latest1, latest2),
  );

  yield* controller.stream;

  await sub1.cancel();
  await sub2.cancel();
}

void _emitMerged(
  StreamController<List<DownloadTask>> controller,
  List<DownloadTask> tasks1,
  List<DownloadTask> tasks2,
) {
  if (controller.isClosed) return;

  // Merge by taskId, preferring non-null/non-empty fields from either list
  final Map<String, DownloadTask> merged = {};

  for (final task in tasks1) {
    merged[task.id] = task;
  }

  for (final task in tasks2) {
    if (merged.containsKey(task.id)) {
      // If task exists in both, merge non-null fields
      final existing = merged[task.id]!;
      merged[task.id] = _mergeTasks(existing, task);
    } else {
      merged[task.id] = task;
    }
  }

  // Sort by createdAt descending (newest first)
  final sorted = merged.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  controller.add(sorted);
}

DownloadTask _mergeTasks(DownloadTask task1, DownloadTask task2) {
  // Prefer task2's non-null values over task1's, but preserve task1's if task2 has defaults
  return task1.copyWith(
    status: task2.status != DownloadStatus.queued ? task2.status : task1.status,
    progress: task2.progress > 0 ? task2.progress : task1.progress,
    speedBps: task2.speedBps ?? task1.speedBps,
    etaSeconds: task2.etaSeconds ?? task1.etaSeconds,
    totalBytes: task2.totalBytes ?? task1.totalBytes,
    downloadedBytes: task2.downloadedBytes ?? task1.downloadedBytes,
    errorMessage: task2.errorMessage ?? task1.errorMessage,
    outputPath: task2.outputPath ?? task1.outputPath,
    completedAt: task2.completedAt ?? task1.completedAt,
    outputFilename: task2.outputFilename ?? task1.outputFilename,
    title: task2.title ?? task1.title,
    thumbnailUrl: task2.thumbnailUrl ?? task1.thumbnailUrl,
    channelName: task2.channelName ?? task1.channelName,
    durationSeconds: task2.durationSeconds ?? task1.durationSeconds,
    selectedFormat: task2.selectedFormat ?? task1.selectedFormat,
    selectedQuality: task2.selectedQuality ?? task1.selectedQuality,
    category: task2.category ?? task1.category,
    destinationFolder: task2.destinationFolder ?? task1.destinationFolder,
  );
}

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

// Python version detection
final pythonVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final result = await Process.run('python', [
      '--version',
    ], runInShell: false);
    if (result.exitCode == 0) {
      final out = result.stdout as String;
      final match = RegExp(r'Python (\d+\.\d+\.\d+)').firstMatch(out);
      return match?.group(1);
    }
  } catch (_) {}
  try {
    final result = await Process.run('python3', [
      '--version',
    ], runInShell: false);
    if (result.exitCode == 0) {
      final out = result.stdout as String;
      final match = RegExp(r'Python (\d+\.\d+\.\d+)').firstMatch(out);
      return match?.group(1);
    }
  } catch (_) {}
  try {
    final result = await Process.run('py', [
      '-3',
      '--version',
    ], runInShell: false);
    if (result.exitCode == 0) {
      final out = result.stdout as String;
      final match = RegExp(r'Python (\d+\.\d+\.\d+)').firstMatch(out);
      return match?.group(1);
    }
  } catch (_) {}
  return null;
});

// ── Dependency provisioning ──────────────────────────────────────────────────

final dependencyProvisionerProvider = Provider<DependencyProvisioner>((ref) {
  return DependencyProvisioner(binDir: AppConfig.instance.binDir);
});

/// Fine-grained installation stages exposed to the UI.
enum ProvisioningStatus {
  idle,
  checking,
  downloading,
  extracting,
  installing,
  verifying,
  installed,
  error,
  // Legacy alias kept for compat — same as [downloading].
  done,
}

class ProvisioningState {
  final ProvisioningStatus status;
  final double progress;
  final String? errorMessage;
  final String? stageLabel;

  const ProvisioningState({
    this.status = ProvisioningStatus.idle,
    this.progress = 0,
    this.errorMessage,
    this.stageLabel,
  });

  ProvisioningState copyWith({
    ProvisioningStatus? status,
    double? progress,
    String? errorMessage,
    String? stageLabel,
    bool clearError = false,
  }) {
    return ProvisioningState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      stageLabel: stageLabel ?? this.stageLabel,
    );
  }
}

class YtDlpProvisioningNotifier extends Notifier<ProvisioningState> {
  @override
  ProvisioningState build() => const ProvisioningState();

  Future<void> provision() async {
    // Prevent duplicate jobs
    if (state.status == ProvisioningStatus.downloading ||
        state.status == ProvisioningStatus.extracting ||
        state.status == ProvisioningStatus.installing ||
        state.status == ProvisioningStatus.verifying ||
        state.status == ProvisioningStatus.checking) {
      return;
    }
    state = const ProvisioningState(
      status: ProvisioningStatus.downloading,
      stageLabel: 'Downloading',
    );
    try {
      await ref
          .read(dependencyProvisionerProvider)
          .provisionYtDlp(
            onProgress: (p) => state = state.copyWith(
              status: ProvisioningStatus.downloading,
              progress: p,
              stageLabel: 'Downloading',
            ),
          );
      YtDlpLocator.instance.invalidate();
      ref.invalidate(ytdlpAvailableProvider);
      ref.invalidate(ytdlpVersionProvider);
      state = const ProvisioningState(
        status: ProvisioningStatus.installed,
        progress: 1,
        stageLabel: 'Installed',
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
    // Prevent duplicate jobs
    if (state.status == ProvisioningStatus.downloading ||
        state.status == ProvisioningStatus.extracting ||
        state.status == ProvisioningStatus.installing ||
        state.status == ProvisioningStatus.verifying ||
        state.status == ProvisioningStatus.checking) {
      return;
    }
    state = const ProvisioningState(
      status: ProvisioningStatus.downloading,
      stageLabel: 'Downloading',
    );
    try {
      await ref
          .read(dependencyProvisionerProvider)
          .provisionFfmpeg(
            onProgress: (p) {
              // Keep state in downloading until onStage changes it
              if (state.status == ProvisioningStatus.downloading ||
                  state.status == ProvisioningStatus.idle) {
                state = state.copyWith(
                  status: ProvisioningStatus.downloading,
                  progress: p,
                );
              }
            },
            onStage: (stage) {
              final status = switch (stage.toLowerCase()) {
                'downloading' => ProvisioningStatus.downloading,
                'extracting' => ProvisioningStatus.extracting,
                'installing' => ProvisioningStatus.installing,
                'verifying' => ProvisioningStatus.verifying,
                _ => ProvisioningStatus.downloading,
              };
              state = state.copyWith(status: status, stageLabel: stage);
            },
          );
      // Invalidate cached path so the new binary is picked up immediately
      (ref.read(ffmpegServiceProvider) as FfmpegServiceImpl).invalidate();
      ref.invalidate(ffmpegAvailableProvider);
      ref.invalidate(ffmpegVersionProvider);
      state = const ProvisioningState(
        status: ProvisioningStatus.installed,
        progress: 1,
        stageLabel: 'Installed',
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

class PythonProvisioningNotifier extends Notifier<ProvisioningState> {
  @override
  ProvisioningState build() => const ProvisioningState();

  Future<void> provision() async {
    state = const ProvisioningState(status: ProvisioningStatus.downloading);
    try {
      // Python provisioning on Windows - download and install portable Python
      // This is a placeholder - full implementation would use the dependency provisioner
      // For now, we show a message directing to python.org
      if (!Platform.isWindows) {
        throw UnsupportedError(
          'Automatic Python provisioning is only supported on Windows. '
          'Please install Python from https://python.org',
        );
      }

      // Use the dependency provisioner to install Python
      await ref
          .read(dependencyProvisionerProvider)
          .provisionPython(
            onProgress: (p) => state = state.copyWith(
              status: ProvisioningStatus.downloading,
              progress: p,
            ),
          );

      ref.invalidate(pythonVersionProvider);
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

final pythonProvisioningProvider =
    NotifierProvider<PythonProvisioningNotifier, ProvisioningState>(
      PythonProvisioningNotifier.new,
    );
