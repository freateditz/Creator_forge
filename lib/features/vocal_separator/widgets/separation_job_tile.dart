import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/separation_job.dart';

class SeparationJobTile extends StatelessWidget {
  final SeparationJob job;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;
  final VoidCallback? onReveal;

  const SeparationJobTile({
    super.key,
    required this.job,
    this.onCancel,
    this.onRetry,
    this.onRemove,
    this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final stageColor = _stageColor(job.stage);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: stageColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _stageIcon(job.stage, stageColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _basename(job.inputPath),
                  style: AppTextStyles.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _actionButtons(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StagePill(job.stage),
              if (job.resolvedDevice != null) ...[
                const SizedBox(width: 6),
                _chip(job.resolvedDevice!.toUpperCase(), AppColors.textMedium),
              ],
              if (job.stage == SeparationStage.completed &&
                  job.outputStems != null) ...[
                const SizedBox(width: 6),
                _chip(
                  '${job.outputStems!.length} stem${job.outputStems!.length != 1 ? "s" : ""}',
                  AppColors.success,
                ),
              ],
            ],
          ),
          if (job.isActive && job.stage == SeparationStage.separating) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: job.progress,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
                minHeight: 4,
              ),
            ),
            if (job.progress != null) ...[
              const SizedBox(height: 4),
              Text(
                '${(job.progress! * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ],
          if (job.isActive && job.stage != SeparationStage.separating) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (job.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              job.errorMessage!,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (job.stage == SeparationStage.completed && job.outputStems != null)
            _StemsList(stems: job.outputStems!),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    if (job.isActive) {
      return IconButton(
        onPressed: onCancel,
        icon: const Icon(Icons.stop_circle_outlined),
        iconSize: 20,
        color: AppColors.error,
        tooltip: 'Cancel',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      );
    }
    if (job.stage == SeparationStage.failed ||
        job.stage == SeparationStage.cancelled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            iconSize: 18,
            color: AppColors.primary,
            tooltip: 'Retry',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            iconSize: 18,
            color: AppColors.textMedium,
            tooltip: 'Remove',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      );
    }
    if (job.stage == SeparationStage.completed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onReveal != null)
            IconButton(
              onPressed: onReveal,
              icon: const Icon(Icons.folder_open_rounded),
              iconSize: 18,
              color: AppColors.success,
              tooltip: 'Reveal in Finder',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            iconSize: 18,
            color: AppColors.textMedium,
            tooltip: 'Remove',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _stageIcon(SeparationStage stage, Color color) {
    if (stage.isActive) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    return Icon(_stageIconData(stage), size: 18, color: color);
  }

  IconData _stageIconData(SeparationStage stage) => switch (stage) {
    SeparationStage.completed => Icons.check_circle_outline_rounded,
    SeparationStage.failed => Icons.error_outline_rounded,
    SeparationStage.cancelled => Icons.cancel_outlined,
    SeparationStage.cancelling => Icons.hourglass_top_rounded,
    _ => Icons.hourglass_empty_rounded,
  };

  Color _stageColor(SeparationStage stage) => switch (stage) {
    SeparationStage.completed => AppColors.success,
    SeparationStage.failed => AppColors.error,
    SeparationStage.cancelled ||
    SeparationStage.cancelling => AppColors.textMedium,
    _ when stage.isActive => AppColors.primary,
    _ => AppColors.textMedium,
  };

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color, fontSize: 10),
      ),
    );
  }

  static String _basename(String path) {
    final idx = path.lastIndexOf(RegExp(r'[/\\]'));
    return idx >= 0 ? path.substring(idx + 1) : path;
  }
}

class _StagePill extends StatelessWidget {
  final SeparationStage stage;

  const _StagePill(this.stage);

  @override
  Widget build(BuildContext context) {
    final color = _color(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        stage.label,
        style: AppTextStyles.labelSmall.copyWith(color: color, fontSize: 10),
      ),
    );
  }

  Color _color(SeparationStage s) => switch (s) {
    SeparationStage.completed => AppColors.success,
    SeparationStage.failed => AppColors.error,
    SeparationStage.cancelled ||
    SeparationStage.cancelling => AppColors.textMedium,
    _ when s.isActive => AppColors.primary,
    _ => AppColors.textMedium,
  };
}

class _StemsList extends StatelessWidget {
  final Map<String, String> stems;

  const _StemsList({required this.stems});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: stems.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Icon(
                  Icons.music_note_rounded,
                  size: 13,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _basename(e.value),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMedium,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _basename(String path) {
    final idx = path.lastIndexOf(RegExp(r'[/\\]'));
    return idx >= 0 ? path.substring(idx + 1) : path;
  }
}
