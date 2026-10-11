import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/app_providers.dart';
import '../../routing/route_paths.dart';
import 'providers/youtube_provider.dart';
import 'widgets/format_selector.dart';
import 'widgets/media_info_card.dart';

class YouTubeScreen extends ConsumerStatefulWidget {
  const YouTubeScreen({super.key});

  @override
  ConsumerState<YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends ConsumerState<YouTubeScreen> {
  final _urlController = TextEditingController();
  final _urlFocus = FocusNode();
  // User-selected output directory (null = use settings default).
  String? _customOutputDir;

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ytState = ref.watch(youTubeProvider);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildDependencyWarning(),
            _buildUrlInput(ytState),
            const SizedBox(height: 20),
            if (ytState.metadataState == MetadataState.loading)
              _buildLoadingState(),
            if (ytState.metadataState == MetadataState.error)
              _buildErrorState(ytState),
            if (ytState.metadataState == MetadataState.success &&
                ytState.mediaInfo != null)
              _buildMediaPanel(ytState, settings),
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
          'YouTube Downloader',
          style: AppTextStyles.displayMedium,
        ).animate().fadeIn(duration: 200.ms),
        const SizedBox(height: 4),
        Text(
          'Download video or audio from YouTube and other supported sites.',
          style: AppTextStyles.bodySmall,
        ).animate().fadeIn(delay: 50.ms, duration: 200.ms),
      ],
    );
  }

  Widget _buildDependencyWarning() {
    final ytdlpAsync = ref.watch(ytdlpAvailableProvider);
    return ytdlpAsync.when(
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
                  'yt-dlp is not installed. Install it with: pip install yt-dlp',
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

  Widget _buildUrlInput(YouTubeState ytState) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _urlController,
            focusNode: _urlFocus,
            style: AppTextStyles.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'Paste a URL (YouTube, or any other supported site)…',
              prefixIcon: Icon(Icons.link, size: 18),
            ),
            onSubmitted: (_) => _fetchMetadata(),
            keyboardType: TextInputType.url,
          ),
        ),
        const SizedBox(width: 10),
        _buildPasteButton(),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: ytState.metadataState == MetadataState.loading
              ? null
              : _fetchMetadata,
          icon: ytState.metadataState == MetadataState.loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.search, size: 16),
          label: const Text('Analyse'),
        ),
        if (ytState.metadataState != MetadataState.idle) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              _urlController.clear();
              ref.read(youTubeProvider.notifier).reset();
            },
            child: const Text('Clear'),
          ),
        ],
      ],
    ).animate().fadeIn(delay: 80.ms, duration: 200.ms);
  }

  Widget _buildPasteButton() {
    return Tooltip(
      message: 'Paste from clipboard (Ctrl+V)',
      child: OutlinedButton(
        onPressed: () async {
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          if (data?.text != null) {
            _urlController.text = data!.text!;
            _fetchMetadata();
          }
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: const Icon(Icons.content_paste_outlined, size: 16),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 14),
              Text(
                'Fetching media information…',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildErrorState(YouTubeState ytState) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ytState.errorMessage ?? 'An error occurred.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
              if (ytState.technicalError != null) ...[
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Technical details',
                    style: AppTextStyles.labelMedium,
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SelectableText(
                        ytState.technicalError!,
                        style: AppTextStyles.mono,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildMediaPanel(YouTubeState ytState, AsyncValue settingsAsync) {
    final info = ytState.mediaInfo!;
    final outputDir =
        _customOutputDir ??
        settingsAsync.valueOrNull?.defaultDownloadsDir ??
        Directory.current.path;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MediaInfoCard(info: info)
            .animate()
            .fadeIn(duration: 250.ms)
            .slideY(begin: 0.04, end: 0),
        const SizedBox(height: 24),
        FormatSelector(
          options: info.availableQualityOptions,
          selected: ytState.selectedQuality,
          onChanged: (opt) =>
              ref.read(youTubeProvider.notifier).selectQuality(opt),
        ).animate().fadeIn(delay: 50.ms, duration: 250.ms),
        const SizedBox(height: 24),
        _buildOutputSection(outputDir),
        const SizedBox(height: 24),
        _buildDownloadButton(ytState, outputDir),
      ],
    );
  }

  Widget _buildOutputSection(String outputDir) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Save to', style: AppTextStyles.headingSmall),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
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
                onPressed: _pickOutputDirectory,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
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
    ).animate().fadeIn(delay: 100.ms, duration: 250.ms);
  }

  Future<void> _pickOutputDirectory() async {
    final path = await getDirectoryPath(confirmButtonText: 'Select');
    if (path != null && mounted) {
      setState(() => _customOutputDir = path);
    }
  }

  Widget _buildDownloadButton(YouTubeState ytState, String outputDir) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: ytState.isEnqueuing
              ? null
              : () => _startDownload(outputDir),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          ),
          icon: ytState.isEnqueuing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download, size: 18),
          label: Text(
            ytState.isEnqueuing ? 'Adding to queue…' : 'Download',
            style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () => context.go(RoutePaths.downloads),
          child: const Text('View queue'),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms, duration: 250.ms);
  }

  void _fetchMetadata() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    ref.read(youTubeProvider.notifier).fetchMetadata(url);
  }

  Future<void> _startDownload(String outputDir) async {
    await ref
        .read(youTubeProvider.notifier)
        .startDownload(outputDirectory: outputDir);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.download, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Added to download queue'),
              const Spacer(),
              TextButton(
                onPressed: () => context.go(RoutePaths.downloads),
                child: const Text(
                  'View',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.surfaceHigher,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      );
    }
  }
}
