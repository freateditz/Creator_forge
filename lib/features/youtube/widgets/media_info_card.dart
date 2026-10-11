import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/media_info.dart';

class MediaInfoCard extends StatelessWidget {
  final MediaInfo info;

  const MediaInfoCard({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildThumbnail(),
          const SizedBox(width: 16),
          Expanded(child: _buildInfo()),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 140,
        height: 80,
        child: info.thumbnailUrl != null
            ? Image.network(
                info.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _thumbnailPlaceholder(),
              )
            : _thumbnailPlaceholder(),
      ),
    );
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      color: AppColors.surfaceElevated,
      child: const Icon(
        Icons.video_file_outlined,
        size: 32,
        color: AppColors.textLow,
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info.title,
          style: AppTextStyles.headingSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (info.uploaderName != null)
              _MetaBadge(icon: Icons.person_outline, label: info.uploaderName!),
            if (info.durationSeconds != null)
              _MetaBadge(
                icon: Icons.schedule,
                label: _formatDuration(info.durationSeconds!),
              ),
            if (info.maxVideoHeight != null)
              _MetaBadge(
                icon: Icons.high_quality_outlined,
                label: 'Up to ${info.maxVideoHeight}p',
              ),
            _MetaBadge(
              icon: Icons.format_list_bulleted,
              label: '${info.formats.length} formats',
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h ${m}m';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textLow),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
