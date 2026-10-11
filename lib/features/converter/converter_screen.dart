import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/app_providers.dart';

// ── Conversion format definitions ───────────────────────────────────────────

enum _FormatCategory { video, audio }

class _ConvertFormat {
  final String id;
  final String label;
  final String extension;
  final _FormatCategory category;
  final Map<String, String> ffmpegArgs;

  const _ConvertFormat({
    required this.id,
    required this.label,
    required this.extension,
    required this.category,
    this.ffmpegArgs = const {},
  });
}

const _videoFormats = [
  _ConvertFormat(
    id: 'mp4_h264',
    label: 'MP4 (H.264)',
    extension: 'mp4',
    category: _FormatCategory.video,
    ffmpegArgs: {'-c:v': 'libx264', '-c:a': 'aac', '-movflags': '+faststart'},
  ),
  _ConvertFormat(
    id: 'mp4_h265',
    label: 'MP4 (H.265 / HEVC)',
    extension: 'mp4',
    category: _FormatCategory.video,
    ffmpegArgs: {'-c:v': 'libx265', '-c:a': 'aac'},
  ),
  _ConvertFormat(
    id: 'mkv',
    label: 'MKV',
    extension: 'mkv',
    category: _FormatCategory.video,
    ffmpegArgs: {'-c:v': 'copy', '-c:a': 'copy'},
  ),
  _ConvertFormat(
    id: 'webm',
    label: 'WebM (VP9)',
    extension: 'webm',
    category: _FormatCategory.video,
    ffmpegArgs: {'-c:v': 'libvpx-vp9', '-c:a': 'libopus'},
  ),
  _ConvertFormat(
    id: 'mov',
    label: 'MOV (ProRes)',
    extension: 'mov',
    category: _FormatCategory.video,
    ffmpegArgs: {'-c:v': 'prores_ks', '-c:a': 'pcm_s16le'},
  ),
  _ConvertFormat(
    id: 'avi',
    label: 'AVI',
    extension: 'avi',
    category: _FormatCategory.video,
    ffmpegArgs: {'-c:v': 'libxvid', '-c:a': 'libmp3lame'},
  ),
];

const _audioFormats = [
  _ConvertFormat(
    id: 'mp3',
    label: 'MP3 (320 kbps)',
    extension: 'mp3',
    category: _FormatCategory.audio,
    ffmpegArgs: {'-vn': '', '-c:a': 'libmp3lame', '-b:a': '320k'},
  ),
  _ConvertFormat(
    id: 'aac',
    label: 'AAC (256 kbps)',
    extension: 'aac',
    category: _FormatCategory.audio,
    ffmpegArgs: {'-vn': '', '-c:a': 'aac', '-b:a': '256k'},
  ),
  _ConvertFormat(
    id: 'm4a',
    label: 'M4A (AAC)',
    extension: 'm4a',
    category: _FormatCategory.audio,
    ffmpegArgs: {'-vn': '', '-c:a': 'aac', '-b:a': '256k'},
  ),
  _ConvertFormat(
    id: 'wav',
    label: 'WAV (PCM)',
    extension: 'wav',
    category: _FormatCategory.audio,
    ffmpegArgs: {'-vn': '', '-c:a': 'pcm_s16le'},
  ),
  _ConvertFormat(
    id: 'flac',
    label: 'FLAC (Lossless)',
    extension: 'flac',
    category: _FormatCategory.audio,
    ffmpegArgs: {'-vn': '', '-c:a': 'flac'},
  ),
  _ConvertFormat(
    id: 'opus',
    label: 'OPUS (128 kbps)',
    extension: 'opus',
    category: _FormatCategory.audio,
    ffmpegArgs: {'-vn': '', '-c:a': 'libopus', '-b:a': '128k', '-ar': '48000'},
  ),
];

// ── State ────────────────────────────────────────────────────────────────────

enum _ConversionStatus { idle, converting, done, error }

class _ConverterState {
  final String? inputPath;
  final _ConvertFormat? selectedFormat;
  final _ConversionStatus status;
  final double progress;
  final String? outputPath;
  final String? errorMessage;

  const _ConverterState({
    this.inputPath,
    this.selectedFormat,
    this.status = _ConversionStatus.idle,
    this.progress = 0,
    this.outputPath,
    this.errorMessage,
  });

  _ConverterState copyWith({
    String? inputPath,
    _ConvertFormat? selectedFormat,
    _ConversionStatus? status,
    double? progress,
    String? outputPath,
    String? errorMessage,
    bool clearError = false,
    bool clearOutput = false,
  }) {
    return _ConverterState(
      inputPath: inputPath ?? this.inputPath,
      selectedFormat: selectedFormat ?? this.selectedFormat,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputPath: clearOutput ? null : (outputPath ?? this.outputPath),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ── Screen ───────────────────────────────────────────────────────────────────

class ConverterScreen extends ConsumerStatefulWidget {
  const ConverterScreen({super.key});

  @override
  ConsumerState<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends ConsumerState<ConverterScreen> {
  _ConverterState _state = const _ConverterState();
  _FormatCategory _activeTab = _FormatCategory.video;

  List<_ConvertFormat> get _formats =>
      _activeTab == _FormatCategory.video ? _videoFormats : _audioFormats;

  void _updateState(_ConverterState Function(_ConverterState) updater) {
    if (mounted) setState(() => _state = updater(_state));
  }

  @override
  Widget build(BuildContext context) {
    final ffmpegAsync = ref.watch(ffmpegAvailableProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFfmpegWarning(ffmpegAsync),
            _buildInputSection(),
            const SizedBox(height: 20),
            if (_state.inputPath != null) ...[
              _buildFormatSection(),
              const SizedBox(height: 20),
              _buildConvertButton(),
              const SizedBox(height: 20),
            ],
            if (_state.status == _ConversionStatus.converting)
              _buildProgressSection(),
            if (_state.status == _ConversionStatus.done) _buildSuccessSection(),
            if (_state.status == _ConversionStatus.error) _buildErrorSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Media Converter',
          style: AppTextStyles.displayMedium,
        ).animate().fadeIn(duration: 200.ms),
        const SizedBox(height: 4),
        Text(
          'Convert between video and audio formats using FFmpeg.',
          style: AppTextStyles.bodySmall,
        ).animate().fadeIn(delay: 50.ms, duration: 200.ms),
      ],
    );
  }

  Widget _buildFfmpegWarning(AsyncValue<bool> ffmpegAsync) {
    return ffmpegAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (available) {
        if (available) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warningSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                color: AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'FFmpeg is not installed or could not be found. '
                  'Install FFmpeg and ensure it is on your PATH.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms);
      },
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Input file', style: AppTextStyles.headingSmall),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickInputFile,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _state.inputPath != null
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
            ),
            child: _state.inputPath == null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.upload_file_outlined,
                        size: 24,
                        color: AppColors.textLow,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Click to select a file, or drag and drop…',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textLow,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.basename(_state.inputPath!),
                              style: AppTextStyles.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _state.inputPath!,
                              style: AppTextStyles.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _pickInputFile,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Change'),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 80.ms, duration: 200.ms);
  }

  Widget _buildFormatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Output format', style: AppTextStyles.headingSmall),
        const SizedBox(height: 10),
        // Category tabs
        Row(
          children: [
            _FormatTab(
              label: 'Video',
              icon: Icons.videocam_outlined,
              isActive: _activeTab == _FormatCategory.video,
              onTap: () => setState(() {
                _activeTab = _FormatCategory.video;
                _state = _state.copyWith(
                  selectedFormat: null,
                  clearOutput: true,
                  clearError: true,
                );
              }),
            ),
            const SizedBox(width: 8),
            _FormatTab(
              label: 'Audio',
              icon: Icons.audiotrack_outlined,
              isActive: _activeTab == _FormatCategory.audio,
              onTap: () => setState(() {
                _activeTab = _FormatCategory.audio;
                _state = _state.copyWith(
                  selectedFormat: null,
                  clearOutput: true,
                  clearError: true,
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _formats.map((fmt) {
            final isSelected = _state.selectedFormat?.id == fmt.id;
            return GestureDetector(
              onTap: () => _updateState((s) => s.copyWith(selectedFormat: fmt)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primarySurface
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  fmt.label,
                  style: AppTextStyles.labelLarge.copyWith(
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
    ).animate().fadeIn(delay: 100.ms, duration: 200.ms);
  }

  Widget _buildConvertButton() {
    final canConvert =
        _state.inputPath != null &&
        _state.selectedFormat != null &&
        _state.status != _ConversionStatus.converting;

    return ElevatedButton.icon(
      onPressed: canConvert ? _startConversion : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      ),
      icon: const Icon(Icons.swap_horiz, size: 18),
      label: Text(
        _state.selectedFormat == null
            ? 'Select a format above'
            : 'Convert to ${_state.selectedFormat!.label}',
        style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
      ),
    ).animate().fadeIn(delay: 120.ms, duration: 200.ms);
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Converting…', style: AppTextStyles.bodyMedium),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _state.progress > 0 ? _state.progress : null,
              minHeight: 6,
            ),
          ),
          if (_state.progress > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${(_state.progress * 100).toStringAsFixed(0)}%',
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildSuccessSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Conversion complete',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          if (_state.outputPath != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: AppColors.textMedium,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      _state.outputPath!,
                      style: AppTextStyles.mono,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => _updateState((_) => const _ConverterState()),
            child: const Text('Convert another file'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildErrorSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _state.errorMessage ?? 'Conversion failed.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _updateState(
                    (s) => s.copyWith(
                      status: _ConversionStatus.idle,
                      clearError: true,
                      clearOutput: true,
                    ),
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Future<void> _pickInputFile() async {
    const typeGroup = XTypeGroup(
      label: 'Media files',
      extensions: [
        'mp4',
        'mkv',
        'avi',
        'mov',
        'webm',
        'flv',
        'wmv',
        'm4v',
        'mp3',
        'wav',
        'flac',
        'aac',
        'm4a',
        'ogg',
        'opus',
        'wma',
      ],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null) {
      _updateState((_) => _ConverterState(inputPath: file.path));
    }
  }

  Future<void> _startConversion() async {
    final fmt = _state.selectedFormat;
    final inputPath = _state.inputPath;
    if (fmt == null || inputPath == null) return;

    final inputDir = p.dirname(inputPath);
    final inputName = p.basenameWithoutExtension(inputPath);
    final outputPath = p.join(inputDir, '$inputName.${fmt.extension}');

    // Avoid overwriting input if same extension
    final resolvedOutput = outputPath == inputPath
        ? p.join(inputDir, '${inputName}_converted.${fmt.extension}')
        : outputPath;

    _updateState(
      (s) => s.copyWith(
        status: _ConversionStatus.converting,
        progress: 0,
        clearError: true,
        clearOutput: true,
      ),
    );

    try {
      // Build args dict, filtering out empty-value flags like '-vn'
      final args = <String, String>{};
      for (final e in fmt.ffmpegArgs.entries) {
        if (e.value.isNotEmpty) {
          args[e.key] = e.value;
        }
      }
      // Handle -vn (no video) as a standalone flag
      final extraArgs = Map<String, String>.from(args);
      if (fmt.ffmpegArgs.containsKey('-vn')) {
        extraArgs['-vn'] = '';
      }

      await ref
          .read(ffmpegServiceProvider)
          .convert(
            inputPath: inputPath,
            outputPath: resolvedOutput,
            extraArgs: extraArgs,
            onProgress: (pct) => _updateState((s) => s.copyWith(progress: pct)),
          );

      _updateState(
        (s) => s.copyWith(
          status: _ConversionStatus.done,
          outputPath: resolvedOutput,
        ),
      );
    } catch (e) {
      _updateState(
        (s) => s.copyWith(
          status: _ConversionStatus.error,
          errorMessage: _friendlyError(e),
        ),
      );
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('FFmpeg is not installed')) {
      return 'FFmpeg is not installed. Install FFmpeg and ensure it is on your PATH.';
    }
    if (msg.contains('Non-zero exit code')) {
      return 'FFmpeg could not convert this file. '
          'The input format may be incompatible with the selected output.';
    }
    return 'Conversion failed: $msg';
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────

class _FormatTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FormatTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? AppColors.primary : AppColors.textMedium,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: isActive ? AppColors.primary : AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
