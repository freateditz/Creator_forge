import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/separation_job.dart';
import '../../models/separation_request.dart';
import '../../providers/app_providers.dart';
import '../../services/separation/model_manager.dart';
import 'widgets/model_install_card.dart';
import 'widgets/separation_job_tile.dart';
import 'widgets/separation_settings_panel.dart';

class VocalSeparatorScreen extends ConsumerStatefulWidget {
  const VocalSeparatorScreen({super.key});

  @override
  ConsumerState<VocalSeparatorScreen> createState() =>
      _VocalSeparatorScreenState();
}

class _VocalSeparatorScreenState extends ConsumerState<VocalSeparatorScreen> {
  String? _selectedFilePath;
  late SeparationRequest _request;

  @override
  void initState() {
    super.initState();
    _request = SeparationRequest(outputDirectory: _defaultOutputDir());
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
    final modelStateAsync = ref.watch(modelManagerStateProvider);
    final jobsAsync = ref.watch(separationJobsProvider);

    final engineReady =
        modelStateAsync.whenOrNull(
          data: (s) => s.status == ModelInstallStatus.installed,
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
                const ModelInstallCard(),
                if (engineReady) ...[
                  const SizedBox(height: 4),
                  SeparationSettingsPanel(
                    request: _request,
                    onChanged: (r) => setState(() => _request = r),
                    selectedFilePath: _selectedFilePath,
                    onPickFile: _pickFile,
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
                        ref.read(separationEngineProvider).cancel(id),
                    onRetry: (id) =>
                        ref.read(separationEngineProvider).retry(id),
                    onRemove: (id) =>
                        ref.read(separationEngineProvider).remove(id),
                    onClearCompleted: jobs.any((j) => j.isTerminal)
                        ? () => ref
                              .read(separationEngineProvider)
                              .clearCompleted()
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
      _selectedFilePath != null &&
      _request.outputDirectory.isNotEmpty;

  Future<void> _pickFile() async {
    final allowed = [
      ...AppConstants.supportedAudioExtensions,
      ...AppConstants.supportedVideoExtensions,
    ];
    final types = [XTypeGroup(label: 'Audio & Video', extensions: allowed)];
    final file = await openFile(acceptedTypeGroups: types);
    if (file != null) {
      setState(() => _selectedFilePath = file.path);
    }
  }

  Future<void> _enqueue() async {
    final path = _selectedFilePath;
    if (path == null) return;
    await ref
        .read(separationEngineProvider)
        .enqueue(inputPath: path, request: _request);
    if (mounted) {
      setState(() => _selectedFilePath = null);
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          const Icon(
            Icons.graphic_eq_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text('Vocal Separator', style: AppTextStyles.headingMedium),
        ],
      ),
    );
  }
}

// ── Job queue ─────────────────────────────────────────────────────────────────

class _JobQueue extends StatelessWidget {
  final List<SeparationJob> jobs;
  final void Function(String id) onCancel;
  final void Function(String id) onRetry;
  final void Function(String id) onRemove;
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
          padding: const EdgeInsets.fromLTRB(22, 8, 16, 6),
          child: Row(
            children: [
              Text('Queue', style: AppTextStyles.labelMedium),
              const Spacer(),
              if (onClearCompleted != null)
                TextButton(
                  onPressed: onClearCompleted,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMedium,
                    textStyle: AppTextStyles.labelSmall,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  child: const Text('Clear completed'),
                ),
            ],
          ),
        ),
        ...jobs.map(
          (job) => SeparationJobTile(
            job: job,
            onCancel: () => onCancel(job.id),
            onRetry: () => onRetry(job.id),
            onRemove: () => onRemove(job.id),
            onReveal: job.outputStems != null
                ? () => _reveal(job.outputStems!.values.first)
                : null,
          ),
        ),
      ],
    );
  }

  void _reveal(String filePath) {
    if (Platform.isMacOS) {
      Process.run('open', ['-R', filePath], runInShell: false).ignore();
    } else if (Platform.isWindows) {
      Process.run('explorer', [
        '/select,',
        filePath,
      ], runInShell: false).ignore();
    }
  }
}
