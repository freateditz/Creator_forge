import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/download_task.dart';
import '../../../providers/app_providers.dart';

class DownloadTaskTile extends ConsumerWidget {
  final DownloadTask task;

  const DownloadTaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title ?? task.url,
                      style: AppTextStyles.headingSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    _buildSubtitle(),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildActions(ref),
            ],
          ),
          if (_showProgress) ...[
            const SizedBox(height: 10),
            _buildProgressBar(),
          ],
          if (task.status == DownloadStatus.failed &&
              task.errorMessage != null) ...[
            const SizedBox(height: 8),
            _buildErrorMessage(),
          ],
        ],
      ),
    );
  }

  bool get _showProgress =>
      task.status == DownloadStatus.downloading ||
      task.status == DownloadStatus.resolving ||
      task.status == DownloadStatus.merging;

  Widget _buildStatusIcon() {
    final (icon, color) = switch (task.status) {
      DownloadStatus.queued => (Icons.schedule, AppColors.statusQueued),
      DownloadStatus.resolving => (Icons.search, AppColors.statusDownloading),
      DownloadStatus.downloading => (
        Icons.downloading,
        AppColors.statusDownloading,
      ),
      DownloadStatus.merging => (Icons.merge, AppColors.statusDownloading),
      DownloadStatus.paused => (
        Icons.pause_circle_outline,
        AppColors.statusPaused,
      ),
      DownloadStatus.completed => (
        Icons.check_circle_outline,
        AppColors.statusCompleted,
      ),
      DownloadStatus.failed => (Icons.error_outline, AppColors.statusFailed),
      DownloadStatus.cancelled => (
        Icons.cancel_outlined,
        AppColors.statusCancelled,
      ),
    };

    if (task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.resolving ||
        task.status == DownloadStatus.merging) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          value: task.status == DownloadStatus.downloading
              ? task.progress
              : null,
          strokeWidth: 2,
          color: color,
        ),
      );
    }

    return Icon(icon, size: 20, color: color);
  }

  Widget _buildSubtitle() {
    final parts = <String>[];

    if (task.channelName != null) parts.add(task.channelName!);

    switch (task.status) {
      case DownloadStatus.downloading:
        if (task.speedBps != null) {
          parts.add(_formatSpeed(task.speedBps!));
        }
        if (task.etaSeconds != null) {
          parts.add('ETA ${_formatEta(task.etaSeconds!)}');
        }
        if (task.totalBytes != null) {
          final dl = task.downloadedBytes != null
              ? '${_formatSize(task.downloadedBytes!)} / '
              : '';
          parts.add('$dl${_formatSize(task.totalBytes!)}');
        }
      case DownloadStatus.completed:
        if (task.totalBytes != null) parts.add(_formatSize(task.totalBytes!));
        if (task.completedAt != null) parts.add('Completed');
      case DownloadStatus.failed:
        parts.add('Failed');
      case DownloadStatus.paused:
        parts.add('Paused');
      case DownloadStatus.queued:
        parts.add('Queued');
      case DownloadStatus.resolving:
        parts.add('Fetching info…');
      case DownloadStatus.merging:
        parts.add('Merging streams…');
      case DownloadStatus.cancelled:
        parts.add('Cancelled');
    }

    return Text(
      parts.join(' · '),
      style: AppTextStyles.caption,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: task.status == DownloadStatus.downloading
                ? task.progress
                : null,
            backgroundColor: AppColors.surfaceHigher,
            color: AppColors.statusDownloading,
            minHeight: 3,
          ),
        ),
        if (task.status == DownloadStatus.downloading) ...[
          const SizedBox(height: 4),
          Text(
            '${(task.progress * 100).toStringAsFixed(1)}%',
            style: AppTextStyles.caption,
          ),
        ],
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Text(
        task.errorMessage!,
        style: AppTextStyles.caption.copyWith(color: AppColors.error),
      ),
    );
  }

  Widget _buildActions(WidgetRef ref) {
    final engine = ref.read(downloadEngineProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.status == DownloadStatus.completed && task.outputPath != null)
          _ActionButton(
            icon: Icons.folder_open_outlined,
            tooltip: 'Open folder',
            onTap: () => _openFolder(task.outputPath!),
          ),
        if (task.status == DownloadStatus.downloading)
          _ActionButton(
            icon: Icons.pause,
            tooltip: 'Pause',
            onTap: () => engine.pause(task.id),
          ),
        if (task.status == DownloadStatus.paused)
          _ActionButton(
            icon: Icons.play_arrow,
            tooltip: 'Resume',
            onTap: () => engine.resume(task.id),
          ),
        if (task.status == DownloadStatus.failed ||
            task.status == DownloadStatus.cancelled)
          _ActionButton(
            icon: Icons.refresh,
            tooltip: 'Retry',
            onTap: () => engine.retry(task.id),
          ),
        if (task.status != DownloadStatus.completed)
          _ActionButton(
            icon:
                task.status == DownloadStatus.downloading ||
                    task.status == DownloadStatus.resolving ||
                    task.status == DownloadStatus.merging
                ? Icons.stop
                : Icons.close,
            tooltip: 'Cancel',
            onTap: () => engine.cancel(task.id),
          ),
        if (task.status == DownloadStatus.completed ||
            task.status == DownloadStatus.failed ||
            task.status == DownloadStatus.cancelled)
          _ActionButton(
            icon: Icons.delete_outline,
            tooltip: 'Remove',
            onTap: () => engine.remove(task.id),
          ),
      ],
    );
  }

  void _openFolder(String filePath) {
    try {
      final dir = File(filePath).parent.path;
      if (Platform.isMacOS) {
        Process.run('open', [dir]);
      } else if (Platform.isWindows) {
        Process.run('explorer', [dir]);
      }
    } catch (_) {}
  }

  String _formatSpeed(int bps) {
    if (bps < 1024) return '${bps}B/s';
    if (bps < 1024 * 1024) return '${(bps / 1024).toStringAsFixed(1)}KB/s';
    return '${(bps / (1024 * 1024)).toStringAsFixed(1)}MB/s';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  String _formatEta(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) {
      return '${seconds ~/ 60}m ${seconds % 60}s';
    }
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: AppColors.textMedium),
        ),
      ),
    );
  }
}
