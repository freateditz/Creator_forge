import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/media_probe_result.dart';
import '../providers/audio_provider.dart';

class FileInputCard extends ConsumerWidget {
  const FileInputCard({super.key});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Text('Input Files', style: AppTextStyles.labelMedium),
                const Spacer(),
                if (state.selectedFiles.isNotEmpty) ...[
                  TextButton(
                    onPressed: notifier.clearFiles,
                    child: Text(
                      'Clear all',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textLow,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  onPressed: () => _pickFiles(ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add files'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryDim,
                    foregroundColor: AppColors.textHigh,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: AppTextStyles.labelSmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (state.selectedFiles.isEmpty)
            _DropZone(onPickFiles: () => _pickFiles(ref))
          else
            _FileList(files: state.selectedFiles, probeCache: state.probeCache),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _pickFiles(WidgetRef ref) async {
    final allowed = [
      ...AppConstants.supportedVideoExtensions,
      ...AppConstants.supportedAudioExtensions,
    ];
    const typeGroup = XTypeGroup(label: 'Media files');
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(label: 'Media files', extensions: allowed),
        typeGroup,
      ],
    );
    if (files.isNotEmpty) {
      await ref
          .read(audioScreenProvider.notifier)
          .addFiles(files.map((f) => f.path).toList());
    }
  }
}

class _DropZone extends StatelessWidget {
  final VoidCallback onPickFiles;
  const _DropZone({required this.onPickFiles});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPickFiles,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.audio_file_outlined,
              size: 32,
              color: AppColors.textLow,
            ),
            const SizedBox(height: 8),
            Text(
              'Click to add audio or video files',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'MP3, WAV, FLAC, AAC, MP4, MKV, MOV…',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textLow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileList extends ConsumerWidget {
  final List<String> files;
  final Map<String, MediaProbeResult> probeCache;

  const _FileList({required this.files, required this.probeCache});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: files.length,
      separatorBuilder: (ctx, i) =>
          const Divider(height: 1, color: AppColors.borderSubtle),
      itemBuilder: (_, index) {
        final path = files[index];
        final probe = probeCache[path];
        return _FileRow(path: path, probe: probe);
      },
    );
  }
}

class _FileRow extends ConsumerWidget {
  final String path;
  final MediaProbeResult? probe;

  const _FileRow({required this.path, this.probe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filename = path.split(RegExp(r'[/\\]')).last;
    final duration = probe?.durationSeconds;
    final codec = probe?.firstAudio?.codecName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            probe?.hasVideo == true
                ? Icons.movie_outlined
                : Icons.audio_file_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (duration != null || codec != null)
                  Text(
                    [
                      if (duration != null) _formatDuration(duration),
                      if (codec != null) codec.toUpperCase(),
                    ].join(' · '),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textLow,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: AppColors.textLow,
            onPressed: () =>
                ref.read(audioScreenProvider.notifier).removeFile(path),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(double seconds) {
    final total = seconds.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
