import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/download_task.dart';
import '../../models/media_info.dart';
import '../../providers/app_providers.dart';
import '../../routing/route_paths.dart';
import 'providers/youtube_provider.dart';
import 'widgets/format_selector.dart';
import 'widgets/media_info_card.dart';
import 'widgets/youtube_download_dialog.dart';

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
    final ffmpegAsync = ref.watch(ffmpegAvailableProvider);
    final ytdlpProvisioning = ref.watch(ytdlpProvisioningProvider);
    final ffmpegProvisioning = ref.watch(ffmpegProvisioningProvider);

    return Column(
      children: [
        ytdlpAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (available) {
            if (available) return const SizedBox.shrink();
            return _buildActionableWarning(
              title: 'yt-dlp not installed',
              message: 'Required for downloading from YouTube and 1000+ sites.',
              icon: Icons.warning_amber_outlined,
              color: AppColors.warning,
              isInstalling: ytdlpProvisioning.status == ProvisioningStatus.downloading,
              progress: ytdlpProvisioning.progress,
              onInstall: () => ref.read(ytdlpProvisioningProvider.notifier).provision(),
              canAutoInstall: Platform.isWindows || Platform.isMacOS,
            );
          },
        ),
        ffmpegAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (available) {
            if (available) return const SizedBox.shrink();
            return _buildActionableWarning(
              title: 'FFmpeg not installed',
              message: 'Required for HD/4K video merging, audio conversion, and AI features.',
              icon: Icons.info_outline,
              color: AppColors.warning,
              isInstalling: ffmpegProvisioning.status == ProvisioningStatus.downloading,
              progress: ffmpegProvisioning.progress,
              onInstall: () => ref.read(ffmpegProvisioningProvider.notifier).provision(),
              canAutoInstall: Platform.isWindows || Platform.isMacOS,
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionableWarning({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    required bool isInstalling,
    required double progress,
    required VoidCallback onInstall,
    required bool canAutoInstall,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: color.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              if (canAutoInstall && !isInstalling) ...[
                const SizedBox(width: 10),
                FilledButton.tonal(
                  onPressed: onInstall,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    backgroundColor: color.withValues(alpha: 0.2),
                    foregroundColor: color,
                  ),
                  child: Text('Install', style: AppTextStyles.labelSmall),
                ),
              ],
            ],
          ),
          if (isInstalling) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 4,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              progress > 0
                  ? 'Downloading… ${(progress * 100).toStringAsFixed(0)}%'
                  : 'Downloading…',
              style: AppTextStyles.caption.copyWith(color: color),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
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
            onSubmitted: (_) => _fetchMetadataAndOpenDialog(),
            keyboardType: TextInputType.url,
          ),
        ),
        const SizedBox(width: 10),
        _buildPasteButton(),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: ytState.metadataState == MetadataState.loading
              ? null
              : _fetchMetadataAndOpenDialog,
          icon: ytState.metadataState == MetadataState.loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download, size: 16),
          label: const Text('Download Options'),
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
      message: 'Paste from clipboard & open download options (Ctrl+V)',
      child: OutlinedButton(
        onPressed: () async {
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          if (data?.text != null && data!.text!.trim().isNotEmpty) {
            _urlController.text = data.text!.trim();
            _fetchMetadataAndOpenDialog();
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

    final List<QualityOption> qualityOptions;
    if (ytState.selectedDownloadType == DownloadType.audioOnly) {
      qualityOptions = info.audioQualityOptions;
    } else if (ytState.selectedDownloadType == DownloadType.videoOnly) {
      qualityOptions = info.videoOnlyQualityOptions;
    } else {
      qualityOptions = info.videoQualityOptions;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MediaInfoCard(info: info)
            .animate()
            .fadeIn(duration: 250.ms)
            .slideY(begin: 0.04, end: 0),
        const SizedBox(height: 20),
        _buildModeSelector(ytState),
        const SizedBox(height: 20),
        FormatSelector(
          options: qualityOptions,
          selected: ytState.selectedQuality,
          onChanged: (opt) =>
              ref.read(youTubeProvider.notifier).selectQuality(opt),
        ).animate().fadeIn(delay: 50.ms, duration: 250.ms),
        const SizedBox(height: 24),
        _buildOutputSection(outputDir),
        const SizedBox(height: 24),
        _buildDownloadButton(ytState, outputDir, info),
      ],
    );
  }

  Widget _buildModeSelector(YouTubeState ytState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Download Mode', style: AppTextStyles.headingSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildModeChip(
              type: DownloadType.videoAndAudio,
              icon: Icons.movie_filter_outlined,
              label: 'Video + Audio',
              selected:
                  ytState.selectedDownloadType == DownloadType.videoAndAudio,
              onTap: () => ref
                  .read(youTubeProvider.notifier)
                  .selectDownloadType(DownloadType.videoAndAudio),
            ),
            _buildModeChip(
              type: DownloadType.videoOnly,
              icon: Icons.videocam_outlined,
              label: 'Video only (silent)',
              selected: ytState.selectedDownloadType == DownloadType.videoOnly,
              onTap: () => ref
                  .read(youTubeProvider.notifier)
                  .selectDownloadType(DownloadType.videoOnly),
            ),
            _buildModeChip(
              type: DownloadType.audioOnly,
              icon: Icons.audiotrack_outlined,
              label: 'Audio only (MP3)',
              selected: ytState.selectedDownloadType == DownloadType.audioOnly,
              onTap: () => ref
                  .read(youTubeProvider.notifier)
                  .selectDownloadType(DownloadType.audioOnly),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeChip({
    required DownloadType type,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.primary : AppColors.textMedium,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? AppColors.primary : AppColors.textHigh,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildDownloadButton(
    YouTubeState ytState,
    String outputDir,
    MediaInfo info,
  ) {
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
            ytState.isEnqueuing ? 'Adding to queue…' : 'Download Now',
            style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => _openDownloadDialog(info),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Options Window…'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () => context.go(RoutePaths.downloads),
          child: const Text('View queue'),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms, duration: 250.ms);
  }

  Future<void> _fetchMetadataAndOpenDialog() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await ref.read(youTubeProvider.notifier).fetchMetadata(url);
    if (!mounted) return;
    final info = ref.read(youTubeProvider).mediaInfo;
    if (info != null) {
      _openDownloadDialog(info);
    }
  }

  Future<void> _openDownloadDialog(MediaInfo info) async {
    final settingsAsync = ref.read(appSettingsProvider);
    final outputDir =
        _customOutputDir ??
        settingsAsync.valueOrNull?.defaultDownloadsDir ??
        Directory.current.path;
    final downloaded = await YouTubeDownloadDialog.show(
      context,
      mediaInfo: info,
      initialOutputDir: outputDir,
    );
    if (downloaded == true && mounted) {
      _showSuccessNotification();
    }
  }

  void _showSuccessNotification() {
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

  Future<void> _startDownload(String outputDir) async {
    await ref
        .read(youTubeProvider.notifier)
        .startDownload(outputDirectory: outputDir);

    if (mounted) {
      _showSuccessNotification();
    }
  }
}
