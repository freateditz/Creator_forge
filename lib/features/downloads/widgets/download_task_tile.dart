import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/download_task.dart';
import '../../../services/download/file_category_classifier.dart';
import '../../../providers/app_providers.dart';

class DownloadTaskTile extends ConsumerWidget {
  final DownloadTask task;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const DownloadTaskTile({
    super.key,
    required this.task,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queuePosition = _getQueuePosition(ref);
    final showQueueBadge =
        queuePosition != null &&
        (task.status == DownloadStatus.queued ||
            task.status == DownloadStatus.resolving);

    return GestureDetector(
      onTap: isSelectionMode ? onTap : null,
      onLongPress: isSelectionMode ? null : onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelectionMode && isSelected
              ? AppColors.primarySurface
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelectionMode && isSelected
                ? AppColors.primary
                : AppColors.border,
            width: isSelectionMode && isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                    activeColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 8),
                ],
                _buildStatusIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title ?? task.url,
                              style: AppTextStyles.headingSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showQueueBadge) ...[
                            const SizedBox(width: 8),
                            _QueuePositionBadge(position: queuePosition),
                          ],
                          if (task.category != null) ...[
                            const SizedBox(width: 8),
                            _CategoryBadge(category: task.category!),
                          ],
                        ],
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
    final segmentedEngine = ref.read(segmentedEngineProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Open file action (completed downloads)
        if (task.status == DownloadStatus.completed && task.outputPath != null)
          _ActionButton(
            icon: Icons.open_in_new,
            tooltip: 'Open file',
            onTap: () => _openFile(task.outputPath!),
          ),
        // Open folder action (completed downloads)
        if (task.status == DownloadStatus.completed && task.outputPath != null)
          _ActionButton(
            icon: Icons.folder_open_outlined,
            tooltip: 'Open folder',
            onTap: () => _openFolder(task.outputPath!),
          ),
        // Copy URL action
        _ActionButton(
          icon: Icons.copy,
          tooltip: 'Copy URL',
          onTap: () => _copyUrlToClipboard(),
        ),
        // Delete downloaded file action (completed)
        if (task.status == DownloadStatus.completed && task.outputPath != null)
          _ActionButton(
            icon: Icons.delete_forever_outlined,
            tooltip: 'Delete downloaded file',
            onTap: () => _confirmDeleteFile(ref),
            color: AppColors.error,
          ),
        // View Error Details action (failed)
        if (task.status == DownloadStatus.failed && task.errorMessage != null)
          _ActionButton(
            icon: Icons.info_outline,
            tooltip: 'View error details',
            onTap: () => _showErrorDetails(ref),
            color: AppColors.error,
          ),
        // Pause
        if (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.resolving ||
            task.status == DownloadStatus.merging)
          _ActionButton(
            icon: Icons.pause,
            tooltip: 'Pause',
            onTap: () {
              engine.pause(task.id);
              segmentedEngine.pause(task.id);
            },
          ),
        // Resume
        if (task.status == DownloadStatus.paused)
          _ActionButton(
            icon: Icons.play_arrow,
            tooltip: 'Resume',
            onTap: () {
              engine.resume(task.id);
              segmentedEngine.resume(task.id);
            },
          ),
        // Retry
        if (task.status == DownloadStatus.failed ||
            task.status == DownloadStatus.cancelled)
          _ActionButton(
            icon: Icons.refresh,
            tooltip: 'Retry',
            onTap: () {
              engine.retry(task.id);
              segmentedEngine.retry(task.id);
            },
          ),
        // Cancel
        if (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.resolving ||
            task.status == DownloadStatus.merging ||
            task.status == DownloadStatus.queued)
          _ActionButton(
            icon: Icons.stop,
            tooltip: 'Cancel',
            onTap: () {
              engine.cancel(task.id);
              segmentedEngine.cancel(task.id);
            },
          ),
        // Remove
        if (task.status == DownloadStatus.completed ||
            task.status == DownloadStatus.failed ||
            task.status == DownloadStatus.cancelled ||
            task.status == DownloadStatus.paused ||
            task.status == DownloadStatus.queued)
          _ActionButton(
            icon: Icons.delete_outline,
            tooltip: 'Remove from list',
            onTap: () {
              engine.remove(task.id);
              segmentedEngine.remove(task.id);
            },
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

  int? _getQueuePosition(WidgetRef ref) {
    final tasks = ref.read(unifiedDownloadTasksProvider).valueOrNull ?? [];
    final queuedTasks = tasks
        .where(
          (t) =>
              t.status == DownloadStatus.queued ||
              t.status == DownloadStatus.resolving,
        )
        .toList();
    queuedTasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final index = queuedTasks.indexWhere((t) => t.id == task.id);
    return index >= 0 ? index + 1 : null;
  }

  void _openFile(String filePath) {
    try {
      launchUrlString('file://$filePath');
    } catch (_) {
      // Fallback to opening folder
      _openFolder(filePath);
    }
  }

  void _copyUrlToClipboard() {
    Clipboard.setData(ClipboardData(text: task.url));
  }

  void _confirmDeleteFile(WidgetRef ref) {
    final context = ref.context;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete downloaded file?'),
        content: Text(
          'This will permanently delete "${task.title ?? task.url}" from your disk. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && task.outputPath != null) {
        try {
          File(task.outputPath!).deleteSync();
          // Remove from history
          ref.read(downloadEngineProvider).remove(task.id);
          ref.read(segmentedEngineProvider).remove(task.id);
        } catch (_) {}
      }
    });
  }

  void _showErrorDetails(WidgetRef ref) {
    final context = ref.context;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error Details'),
        content: SelectableText(task.errorMessage ?? 'Unknown error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: task.errorMessage ?? ''));
              Navigator.pop(ctx);
            },
            child: const Text('Copy error'),
          ),
        ],
      ),
    );
  }
}

class _QueuePositionBadge extends StatelessWidget {
  final int position;

  const _QueuePositionBadge({required this.position});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Text(
        '#$position',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final FileCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (category) {
      FileCategory.videos => ('Videos', AppColors.primary),
      FileCategory.music => ('Music', Colors.purple),
      FileCategory.documents => ('Documents', Colors.blue),
      FileCategory.compressed => ('Compressed', Colors.orange),
      FileCategory.programs => ('Programs', Colors.green),
      FileCategory.images => ('Images', Colors.pink),
      FileCategory.other => ('Other', AppColors.textLow),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
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
          child: Icon(icon, size: 16, color: color ?? AppColors.textMedium),
        ),
      ),
    );
  }
}
