import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/download_task.dart';
import '../../../models/media_info.dart';
import '../../../providers/app_providers.dart';
import '../providers/youtube_provider.dart';

class YouTubeDownloadDialog extends ConsumerStatefulWidget {
  final MediaInfo mediaInfo;
  final String? initialOutputDir;

  const YouTubeDownloadDialog({
    super.key,
    required this.mediaInfo,
    this.initialOutputDir,
  });

  static Future<bool?> show(
    BuildContext context, {
    required MediaInfo mediaInfo,
    String? initialOutputDir,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => YouTubeDownloadDialog(
        mediaInfo: mediaInfo,
        initialOutputDir: initialOutputDir,
      ),
    );
  }

  @override
  ConsumerState<YouTubeDownloadDialog> createState() =>
      _YouTubeDownloadDialogState();
}

class _YouTubeDownloadDialogState extends ConsumerState<YouTubeDownloadDialog> {
  late DownloadType _selectedMode;
  late QualityOption _selectedQuality;
  String? _customOutputDir;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = DownloadType.videoAndAudio;
    _selectedQuality = QualityOption.best;
    _customOutputDir = widget.initialOutputDir;
  }

  void _onModeChanged(DownloadType mode) {
    setState(() {
      _selectedMode = mode;
      if (mode == DownloadType.audioOnly) {
        _selectedQuality = QualityOption.audioBest;
      } else if (mode == DownloadType.videoOnly) {
        _selectedQuality = QualityOption.bestVideoOnly;
      } else {
        _selectedQuality = QualityOption.best;
      }
    });
  }

  Future<void> _pickDirectory() async {
    final path = await getDirectoryPath(confirmButtonText: 'Select folder');
    if (path != null && mounted) {
      setState(() => _customOutputDir = path);
    }
  }

  Future<void> _handleDownload(String finalOutputDir) async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(youTubeProvider.notifier)
          .startDownload(
            outputDirectory: finalOutputDir,
            downloadType: _selectedMode,
            qualityOption: _selectedQuality,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start download: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final defaultDir =
        settingsAsync.valueOrNull?.defaultDownloadsDir ??
        Directory.current.path;
    final outputDir = _customOutputDir ?? defaultDir;

    return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const Divider(height: 1, color: AppColors.border),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMediaPreview(),
                        const SizedBox(height: 20),
                        _buildModeSelector(),
                        const SizedBox(height: 20),
                        _buildQualitySection(),
                        const SizedBox(height: 20),
                        _buildDestinationSection(outputDir),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildFooterActions(context, outputDir),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 200.ms)
        .scale(begin: const Offset(0.97, 0.97), end: const Offset(1, 1));
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.play_circle_filled,
              color: Color(0xFFFF0000),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text('Download Options', style: AppTextStyles.headingLarge),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.textMedium,
            onPressed: () => Navigator.of(context).pop(false),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    final info = widget.mediaInfo;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 120,
              height: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (info.thumbnailUrl != null)
                    CachedNetworkImage(
                      imageUrl: info.thumbnailUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: AppColors.surfaceHigher,
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.surfaceHigher,
                        child: const Icon(
                          Icons.video_library,
                          size: 28,
                          color: AppColors.textLow,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: AppColors.surfaceHigher,
                      child: const Icon(
                        Icons.video_library,
                        size: 28,
                        color: AppColors.textLow,
                      ),
                    ),
                  if (info.durationSeconds != null)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(info.durationSeconds!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (info.uploaderName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppColors.textMedium,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          info.uploaderName!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMedium,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Download Type',
          style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMedium),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildModeCard(
                type: DownloadType.videoAndAudio,
                icon: Icons.movie_creation_outlined,
                title: 'Video + Audio',
                subtitle: 'Full video with sound',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModeCard(
                type: DownloadType.videoOnly,
                icon: Icons.videocam_outlined,
                title: 'Video only',
                subtitle: 'Silent video stream',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModeCard(
                type: DownloadType.audioOnly,
                icon: Icons.audiotrack_outlined,
                title: 'Audio only',
                subtitle: 'MP3 / M4A music track',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required DownloadType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedMode == type;
    return InkWell(
      onTap: () => _onModeChanged(type),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primarySurface
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? AppColors.primary : AppColors.textMedium,
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.primary,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textHigh,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.8)
                    : AppColors.textLow,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualitySection() {
    final List<QualityOption> options;
    if (_selectedMode == DownloadType.audioOnly) {
      options = widget.mediaInfo.audioQualityOptions;
    } else if (_selectedMode == DownloadType.videoOnly) {
      options = widget.mediaInfo.videoOnlyQualityOptions;
    } else {
      options = widget.mediaInfo.videoQualityOptions;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _selectedMode == DownloadType.audioOnly
                  ? 'Audio Quality'
                  : 'Video Resolution',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textMedium,
              ),
            ),
            const Spacer(),
            if (_selectedMode == DownloadType.videoAndAudio)
              Text(
                'Audio included in MP4',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.success,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected =
                opt.label == _selectedQuality.label ||
                opt.formatSelector == _selectedQuality.formatSelector;
            return _buildQualityChip(opt, isSelected);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQualityChip(QualityOption opt, bool isSelected) {
    final isAvailable = opt.available;
    return InkWell(
      onTap: isAvailable ? () => setState(() => _selectedQuality = opt) : null,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primarySurface
              : isAvailable
              ? AppColors.surfaceElevated
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
            ],
            Text(
              opt.label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected
                    ? AppColors.primary
                    : isAvailable
                    ? AppColors.textHigh
                    : AppColors.textDisabled,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                decoration: isAvailable ? null : TextDecoration.lineThrough,
              ),
            ),
            if (!isAvailable) ...[
              const SizedBox(width: 6),
              Text(
                'N/A',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textDisabled,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationSection(String outputDir) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Save to',
          style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMedium),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                color: AppColors.textMedium,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  outputDir,
                  style: AppTextStyles.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _pickDirectory,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  'Browse…',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterActions(BuildContext context, String outputDir) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _isSubmitting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : () => _handleDownload(outputDir),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download, size: 18),
            label: Text(_isSubmitting ? 'Adding…' : 'Download Now'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final remM = m % 60;
      return '$h:${remM.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
