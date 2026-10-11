import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/bg_removal_job.dart';
import '../../models/bg_removal_request.dart';
import '../../providers/app_providers.dart';
import '../../services/bg_removal/image_model_manager.dart';
import 'widgets/bg_removal_job_tile.dart';
import 'widgets/bg_removal_settings_panel.dart';
import 'widgets/image_model_install_card.dart';

class BackgroundRemoverScreen extends ConsumerStatefulWidget {
  const BackgroundRemoverScreen({super.key});

  @override
  ConsumerState<BackgroundRemoverScreen> createState() =>
      _BackgroundRemoverScreenState();
}

class _BackgroundRemoverScreenState
    extends ConsumerState<BackgroundRemoverScreen> {
  final List<String> _selectedPaths = [];
  late BgRemovalRequest _request;

  @override
  void initState() {
    super.initState();
    _request = BgRemovalRequest(outputDirectory: _defaultOutputDir());
  }

  String _defaultOutputDir() {
    try {
      return AppConfig.instance.defaultDownloadsDir;
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final modelStateAsync = ref.watch(imageModelManagerStateProvider);
    final jobsAsync = ref.watch(bgRemovalJobsProvider);

    final engineReady =
        modelStateAsync.whenOrNull(
          data: (s) => s.status == ImageModelInstallStatus.installed,
        ) ??
        false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(),
          Expanded(
            child: ListView(
              children: [
                const ImageModelInstallCard(),
                if (engineReady) ...[
                  const SizedBox(height: 4),
                  BgRemovalSettingsPanel(
                    request: _request,
                    onChanged: (r) => setState(() => _request = r),
                    selectedFilePaths: _selectedPaths,
                    onPickFiles: _pickFiles,
                    onClearFiles: () => setState(() => _selectedPaths.clear()),
                    canEnqueue: _canEnqueue(engineReady),
                    onEnqueue: _canEnqueue(engineReady) ? _enqueue : null,
                  ),
                ],
                const SizedBox(height: 4),
                jobsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                  data: (jobs) => _JobQueue(
                    jobs: jobs,
                    onCancel: (id) =>
                        ref.read(bgRemovalEngineProvider).cancel(id),
                    onRetry: (id) =>
                        ref.read(bgRemovalEngineProvider).retry(id),
                    onRemove: (id) =>
                        ref.read(bgRemovalEngineProvider).remove(id),
                    onClearCompleted: jobs.any((j) => j.isTerminal)
                        ? () =>
                              ref.read(bgRemovalEngineProvider).clearCompleted()
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canEnqueue(bool engineReady) =>
      engineReady &&
      _selectedPaths.isNotEmpty &&
      _request.outputDirectory.isNotEmpty;

  Future<void> _pickFiles() async {
    const typeGroup = XTypeGroup(
      label: 'Images',
      extensions: AppConstants.supportedImageExtensions,
    );
    final files = await openFiles(acceptedTypeGroups: [typeGroup]);
    if (files.isEmpty) return;
    setState(() {
      for (final f in files) {
        if (!_selectedPaths.contains(f.path)) {
          _selectedPaths.add(f.path);
        }
      }
    });
  }

  Future<void> _enqueue() async {
    if (!_canEnqueue(true)) return;
    final engine = ref.read(bgRemovalEngineProvider);
    for (final path in List<String>.from(_selectedPaths)) {
      await engine.enqueue(inputPath: path, request: _request);
    }
    setState(() => _selectedPaths.clear());
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_fix_high_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Background Remover', style: AppTextStyles.headingLarge),
              Text(
                'Local AI — images never leave your device',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JobQueue extends StatelessWidget {
  final List<BgRemovalJob> jobs;
  final ValueChanged<String> onCancel;
  final ValueChanged<String> onRetry;
  final ValueChanged<String> onRemove;
  final VoidCallback? onClearCompleted;

  const _JobQueue({
    required this.jobs,
    required this.onCancel,
    required this.onRetry,
    required this.onRemove,
    this.onClearCompleted,
  });

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Text('Jobs', style: AppTextStyles.headingSmall),
              Text(' · ${jobs.length}', style: AppTextStyles.bodySmall),
              const Spacer(),
              if (onClearCompleted != null)
                TextButton(
                  onPressed: onClearCompleted,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMedium,
                    textStyle: AppTextStyles.labelSmall,
                  ),
                  child: const Text('Clear completed'),
                ),
            ],
          ),
        ),
        for (final job in jobs)
          BgRemovalJobTile(
            key: ValueKey(job.id),
            job: job,
            onCancel: job.isActive ? () => onCancel(job.id) : null,
            onRetry:
                (job.stage == BgRemovalStage.failed ||
                    job.stage == BgRemovalStage.cancelled)
                ? () => onRetry(job.id)
                : null,
            onRemove: job.isTerminal ? () => onRemove(job.id) : null,
            onReveal:
                job.stage == BgRemovalStage.completed && job.outputPath != null
                ? () => _reveal(job.outputPath!)
                : null,
          ),
      ],
    );
  }

  void _reveal(String filePath) {
    if (!File(filePath).existsSync()) return;
    if (Platform.isMacOS) {
      Process.run('open', ['-R', filePath], runInShell: false).ignore();
    } else if (Platform.isWindows) {
      Process.run('explorer.exe', [
        '/select,',
        p.windows.normalize(filePath),
      ], runInShell: false).ignore();
    }
  }
}
