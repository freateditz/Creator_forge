import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/audio_format.dart';
import '../../providers/app_providers.dart';
import 'providers/audio_provider.dart';
import 'widgets/audio_job_tile.dart';
import 'widgets/file_input_card.dart';
import 'widgets/format_options_panel.dart';

class AudioScreen extends ConsumerWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: config panel
          SizedBox(width: 340, child: _ConfigPanel()),
          const VerticalDivider(width: 1, color: AppColors.border),
          // Right: queue
          const Expanded(child: _QueuePanel()),
        ],
      ),
    );
  }
}

// ── Left panel ────────────────────────────────────────────────────────────────

class _ConfigPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioScreenProvider);
    final notifier = ref.read(audioScreenProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text('Audio Tools', style: AppTextStyles.headingMedium),
        ),
        const SizedBox(height: 16),

        // Tab selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _TabBar(selected: state.activeTab, onChanged: notifier.setTab),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FileInputCard(),
                const SizedBox(height: 16),
                if (state.activeTab != AudioTab.extract)
                  const FormatOptionsPanel()
                else
                  _ExtractFormatPicker(),
                const SizedBox(height: 16),
                _OutputDirRow(
                  dir: state.outputDirectory,
                  onPick: () => _pickOutputDir(ref),
                ),
                const SizedBox(height: 20),
                _StartButton(state: state),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickOutputDir(WidgetRef ref) async {
    final dir = await getDirectoryPath(
      confirmButtonText: 'Select output folder',
    );
    if (dir != null) {
      ref.read(audioScreenProvider.notifier).setOutputDirectory(dir);
    }
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final AudioTab selected;
  final void Function(AudioTab) onChanged;

  const _TabBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: AudioTab.values.map((tab) {
          final isSelected = tab == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primarySurface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: isSelected
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        )
                      : null,
                ),
                child: Text(
                  _tabLabel(tab),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textMedium,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _tabLabel(AudioTab t) => switch (t) {
    AudioTab.extract => 'Extract',
    AudioTab.convert => 'Convert',
    AudioTab.batch => 'Batch',
  };
}

// ── Extract quick-format picker ───────────────────────────────────────────────

class _ExtractFormatPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioScreenProvider);
    final notifier = ref.read(audioScreenProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Extract as', style: AppTextStyles.labelMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AudioOutputFormat.values.map((fmt) {
              final isSelected = fmt == state.outputFormat;
              return GestureDetector(
                onTap: () => notifier.setOutputFormat(fmt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primarySurface
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    fmt.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textMedium,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Output directory row ──────────────────────────────────────────────────────

class _OutputDirRow extends StatelessWidget {
  final String? dir;
  final VoidCallback onPick;

  const _OutputDirRow({required this.dir, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Output folder',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMedium),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: AppColors.textLow,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dir ?? 'Default (Music/CreatorForge)',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: dir != null
                          ? AppColors.textHigh
                          : AppColors.textLow,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textLow,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Start button ──────────────────────────────────────────────────────────────

class _StartButton extends ConsumerWidget {
  final AudioScreenState state;
  const _StartButton({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canStart = state.selectedFiles.isNotEmpty && !state.isProbing;
    final engine = ref.read(audioEngineProvider);
    final label = state.activeTab == AudioTab.batch
        ? 'Process ${state.selectedFiles.length} file${state.selectedFiles.length == 1 ? '' : 's'}'
        : state.activeTab == AudioTab.extract
        ? 'Extract Audio'
        : 'Convert Audio';

    return FilledButton(
      onPressed: canStart ? () => _start(ref, engine) : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.surfaceHigher,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: AppTextStyles.labelMedium),
    );
  }

  Future<void> _start(WidgetRef ref, dynamic engine) async {
    final s = ref.read(audioScreenProvider);
    final request = s.buildRequest();
    for (final path in s.selectedFiles) {
      await engine.enqueue(inputPath: path, request: request);
    }
    ref.read(audioScreenProvider.notifier).clearFiles();
  }
}

// ── Right panel: queue ────────────────────────────────────────────────────────

class _QueuePanel extends ConsumerWidget {
  const _QueuePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(audioJobsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              Text('Queue', style: AppTextStyles.headingMedium),
              const Spacer(),
              jobs.maybeWhen(
                data: (list) {
                  final hasTerminal = list.any((j) => j.isTerminal);
                  if (!hasTerminal) return const SizedBox.shrink();
                  return TextButton.icon(
                    onPressed: () =>
                        ref.read(audioEngineProvider).clearCompleted(),
                    icon: const Icon(
                      Icons.cleaning_services_outlined,
                      size: 15,
                    ),
                    label: const Text('Clear completed'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textLow,
                      textStyle: AppTextStyles.labelSmall,
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: jobs.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            error: (e, st) => Center(
              child: Text(
                'Could not load jobs.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textLow,
                ),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.queue_music_outlined,
                        size: 48,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No jobs yet',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textLow,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add files and press Start to begin.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: list.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (_, index) => AudioJobTile(
                  key: ValueKey(list[index].id),
                  job: list[index],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
