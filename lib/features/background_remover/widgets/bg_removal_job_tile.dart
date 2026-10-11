import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/bg_removal_job.dart';

class BgRemovalJobTile extends StatelessWidget {
  final BgRemovalJob job;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;
  final VoidCallback? onReveal;

  const BgRemovalJobTile({
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
          // Header row
          Row(
            children: [
              _stageIconWidget(job.stage, stageColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.basename(job.inputPath),
                  style: AppTextStyles.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _ActionButtons(
                job: job,
                onCancel: onCancel,
                onRetry: onRetry,
                onRemove: onRemove,
                onReveal: onReveal,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Stage row
          Row(
            children: [
              _StagePill(job.stage),
              if (job.stage == BgRemovalStage.completed &&
                  job.outputWidth != null) ...[
                const SizedBox(width: 6),
                _chip(
                  '${job.outputWidth}×${job.outputHeight}',
                  AppColors.textMedium,
                ),
              ],
              if (job.stage == BgRemovalStage.completed &&
                  job.outputFileSize != null) ...[
                const SizedBox(width: 6),
                _chip(_formatBytes(job.outputFileSize!), AppColors.textMedium),
              ],
              if (job.stage == BgRemovalStage.completed) ...[
                const SizedBox(width: 6),
                _chip('PNG + Alpha', AppColors.success),
              ],
            ],
          ),
          // Indeterminate progress for active stages
          if (job.isActive) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 4,
              ),
            ),
          ],
          // Error message
          if (job.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              job.errorMessage!,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Before / After thumbnails when completed
          if (job.stage == BgRemovalStage.completed &&
              job.outputPath != null) ...[
            const SizedBox(height: 10),
            _BeforeAfterRow(
              inputPath: job.inputPath,
              outputPath: job.outputPath!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _stageIconWidget(BgRemovalStage stage, Color color) {
    if (stage == BgRemovalStage.completed) {
      return Icon(Icons.check_circle_outline_rounded, color: color, size: 18);
    }
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
    return Icon(_stageIcon(stage), color: color, size: 18);
  }

  IconData _stageIcon(BgRemovalStage stage) => switch (stage) {
    BgRemovalStage.pending => Icons.hourglass_empty_rounded,
    BgRemovalStage.failed => Icons.error_outline_rounded,
    BgRemovalStage.cancelled ||
    BgRemovalStage.cancelling => Icons.cancel_outlined,
    _ => Icons.auto_fix_high_rounded,
  };

  Color _stageColor(BgRemovalStage stage) => switch (stage) {
    BgRemovalStage.completed => AppColors.success,
    BgRemovalStage.failed => AppColors.error,
    BgRemovalStage.cancelled ||
    BgRemovalStage.cancelling => AppColors.textMedium,
    BgRemovalStage.pending => AppColors.textMedium,
    _ => AppColors.info,
  };

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
  );

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _StagePill extends StatelessWidget {
  final BgRemovalStage stage;

  const _StagePill(this.stage);

  @override
  Widget build(BuildContext context) {
    final color = _color(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        stage.label,
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }

  Color _color(BgRemovalStage stage) => switch (stage) {
    BgRemovalStage.completed => AppColors.success,
    BgRemovalStage.failed => AppColors.error,
    BgRemovalStage.cancelled ||
    BgRemovalStage.cancelling => AppColors.textMedium,
    BgRemovalStage.pending => AppColors.textMedium,
    _ => AppColors.info,
  };
}

class _ActionButtons extends StatelessWidget {
  final BgRemovalJob job;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;
  final VoidCallback? onReveal;

  const _ActionButtons({
    required this.job,
    this.onCancel,
    this.onRetry,
    this.onRemove,
    this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (job.isActive && onCancel != null)
          _iconBtn(Icons.stop_rounded, AppColors.error, onCancel!),
        if (job.stage == BgRemovalStage.completed && onReveal != null)
          _iconBtn(Icons.folder_open_rounded, AppColors.textMedium, onReveal!),
        if ((job.stage == BgRemovalStage.failed ||
                job.stage == BgRemovalStage.cancelled) &&
            onRetry != null)
          _iconBtn(Icons.refresh_rounded, AppColors.info, onRetry!),
        if (job.isTerminal && onRemove != null)
          _iconBtn(Icons.close_rounded, AppColors.textMedium, onRemove!),
      ],
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onPressed) =>
      IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        color: color,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        splashRadius: 16,
      );
}

/// Displays the original and result thumbnails side-by-side with a
/// checkerboard background to show the transparency.
class _BeforeAfterRow extends StatelessWidget {
  final String inputPath;
  final String outputPath;

  const _BeforeAfterRow({required this.inputPath, required this.outputPath});

  @override
  Widget build(BuildContext context) {
    final outputExists = File(outputPath).existsSync();

    return Row(
      children: [
        _ThumbPanel(
          label: 'Original',
          imagePath: inputPath,
          showCheckerboard: false,
        ),
        const SizedBox(width: 8),
        const Icon(
          Icons.arrow_forward_rounded,
          size: 16,
          color: AppColors.textMedium,
        ),
        const SizedBox(width: 8),
        _ThumbPanel(
          label: 'Result',
          imagePath: outputExists ? outputPath : null,
          showCheckerboard: true,
        ),
      ],
    );
  }
}

class _ThumbPanel extends StatelessWidget {
  final String label;
  final String? imagePath;
  final bool showCheckerboard;

  const _ThumbPanel({
    required this.label,
    required this.imagePath,
    required this.showCheckerboard,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        SizedBox(
          width: 100,
          height: 72,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showCheckerboard) const _Checkerboard(),
                if (imagePath != null)
                  Image.file(
                    File(imagePath!),
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, st) => const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: AppColors.textMedium,
                        size: 24,
                      ),
                    ),
                  )
                else
                  const ColoredBox(
                    color: AppColors.surfaceElevated,
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        color: AppColors.textMedium,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A tiled checkerboard pattern used as the transparency indicator behind
/// PNG results. This is display-only — not included in exported files.
class _Checkerboard extends StatelessWidget {
  const _Checkerboard();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CheckerboardPainter());
}

class _CheckerboardPainter extends CustomPainter {
  static const _light = Color(0xFFCCCCCC);
  static const _dark = Color(0xFF999999);
  static const _cellSize = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paintLight = Paint()..color = _light;
    final paintDark = Paint()..color = _dark;

    final cols = (size.width / _cellSize).ceil() + 1;
    final rows = (size.height / _cellSize).ceil() + 1;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(
          c * _cellSize,
          r * _cellSize,
          _cellSize,
          _cellSize,
        );
        canvas.drawRect(rect, (r + c).isEven ? paintLight : paintDark);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter old) => false;
}
