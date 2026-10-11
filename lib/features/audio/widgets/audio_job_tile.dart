import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/processing_job.dart';
import '../../../providers/app_providers.dart';
import '../../../services/audio/audio_processing_engine.dart';

class AudioJobTile extends ConsumerWidget {
  final AudioJob job;
  const AudioJobTile({super.key, required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.read(audioEngineProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusIcon(status: job.status),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.inputPath.split(RegExp(r'[/\\]')).last,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _subtitle(job),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textLow,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ActionButtons(job: job, engine: engine),
            ],
          ),
          if (job.status == ProcessingJobStatus.processing) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: job.progress > 0 ? job.progress : null,
                minHeight: 3,
                backgroundColor: AppColors.surfaceHigher,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                job.progress > 0
                    ? '${(job.progress * 100).toStringAsFixed(0)}%'
                    : 'Processing…',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textLow,
                ),
              ),
            ),
          ],
          if (job.status == ProcessingJobStatus.failed &&
              job.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                job.errorMessage!,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ],
          if (job.status == ProcessingJobStatus.completed &&
              job.outputPath != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _revealInFinder(job.outputPath!),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_open,
                    size: 13,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      job.outputPath!,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.success,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _subtitle(AudioJob job) {
    final fmt = job.request.outputFormat.label;
    final op = job.request.operation.name;
    return switch (job.status) {
      ProcessingJobStatus.pending => '$op → $fmt · Queued',
      ProcessingJobStatus.processing => '$op → $fmt',
      ProcessingJobStatus.completed => '$op → $fmt · Done',
      ProcessingJobStatus.failed => '$op → $fmt · Failed',
      ProcessingJobStatus.cancelled => '$op → $fmt · Cancelled',
    };
  }

  void _revealInFinder(String path) {
    final dir = path.substring(0, path.lastIndexOf(Platform.pathSeparator));
    if (Platform.isMacOS) {
      Process.run('open', [dir]).ignore();
    } else if (Platform.isWindows) {
      Process.run('explorer', [dir]).ignore();
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final ProcessingJobStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ProcessingJobStatus.pending => const Icon(
        Icons.schedule,
        size: 18,
        color: AppColors.statusQueued,
      ),
      ProcessingJobStatus.processing => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
        ),
      ),
      ProcessingJobStatus.completed => const Icon(
        Icons.check_circle_outline,
        size: 18,
        color: AppColors.statusCompleted,
      ),
      ProcessingJobStatus.failed => const Icon(
        Icons.error_outline,
        size: 18,
        color: AppColors.statusFailed,
      ),
      ProcessingJobStatus.cancelled => const Icon(
        Icons.cancel_outlined,
        size: 18,
        color: AppColors.statusCancelled,
      ),
    };
  }
}

class _ActionButtons extends StatelessWidget {
  final AudioJob job;
  final AudioProcessingEngine engine;
  const _ActionButtons({required this.job, required this.engine});

  @override
  Widget build(BuildContext context) {
    return switch (job.status) {
      ProcessingJobStatus.processing ||
      ProcessingJobStatus.pending => IconButton(
        icon: const Icon(Icons.close, size: 16),
        color: AppColors.textLow,
        tooltip: 'Cancel',
        onPressed: () => engine.cancel(job.id),
      ),
      ProcessingJobStatus.failed || ProcessingJobStatus.cancelled => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            color: AppColors.primary,
            tooltip: 'Retry',
            onPressed: () => engine.retry(job.id),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            color: AppColors.textLow,
            tooltip: 'Remove',
            onPressed: () => engine.remove(job.id),
          ),
        ],
      ),
      ProcessingJobStatus.completed => IconButton(
        icon: const Icon(Icons.delete_outline, size: 16),
        color: AppColors.textLow,
        tooltip: 'Remove',
        onPressed: () => engine.remove(job.id),
      ),
    };
  }
}
