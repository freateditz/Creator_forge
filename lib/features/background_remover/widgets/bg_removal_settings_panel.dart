import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/bg_removal_request.dart';

class BgRemovalSettingsPanel extends StatefulWidget {
  final BgRemovalRequest request;
  final ValueChanged<BgRemovalRequest> onChanged;
  final List<String> selectedFilePaths;
  final VoidCallback? onPickFiles;
  final VoidCallback? onClearFiles;
  final bool canEnqueue;
  final VoidCallback? onEnqueue;

  const BgRemovalSettingsPanel({
    super.key,
    required this.request,
    required this.onChanged,
    required this.selectedFilePaths,
    this.onPickFiles,
    this.onClearFiles,
    required this.canEnqueue,
    this.onEnqueue,
  });

  @override
  State<BgRemovalSettingsPanel> createState() => _BgRemovalSettingsPanelState();
}

class _BgRemovalSettingsPanelState extends State<BgRemovalSettingsPanel> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Source Images', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          _ImagePicker(
            paths: widget.selectedFilePaths,
            onPick: widget.onPickFiles,
            onClear: widget.onClearFiles,
          ),
          const SizedBox(height: 16),
          Text('Model', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          _ModelSelector(
            value: widget.request.model,
            onChanged: (m) =>
                widget.onChanged(widget.request.copyWith(model: m)),
          ),
          const SizedBox(height: 16),
          _OutputDirRow(
            path: widget.request.outputDirectory,
            onChanged: (dir) =>
                widget.onChanged(widget.request.copyWith(outputDirectory: dir)),
          ),
          const SizedBox(height: 12),
          // Advanced refinement options
          InkWell(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _showAdvanced
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: AppColors.textMedium,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Advanced Edge Refinement',
                    style: AppTextStyles.labelMedium,
                  ),
                ],
              ),
            ),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: 8),
            _AdvancedOptions(
              request: widget.request,
              onChanged: widget.onChanged,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.canEnqueue ? widget.onEnqueue : null,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: Text(
                widget.selectedFilePaths.length > 1
                    ? 'Remove Background (${widget.selectedFilePaths.length} images)'
                    : 'Remove Background',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: AppTextStyles.labelMedium,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Background removal is model-based. Results vary by image complexity. '
            'Fine hair, transparent objects, and complex backgrounds may require '
            'manual refinement.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _ImagePicker extends StatelessWidget {
  final List<String> paths;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  const _ImagePicker({required this.paths, this.onPick, this.onClear});

  @override
  Widget build(BuildContext context) {
    final hasFiles = paths.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasFiles
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasFiles
                      ? Icons.photo_library_rounded
                      : Icons.add_photo_alternate_rounded,
                  size: 18,
                  color: hasFiles ? AppColors.primary : AppColors.textMedium,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasFiles
                        ? '${paths.length} image${paths.length != 1 ? "s" : ""} selected'
                        : 'Tap to pick images…',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: hasFiles
                          ? AppColors.textHigh
                          : AppColors.textMedium,
                    ),
                  ),
                ),
                if (hasFiles && onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.textMedium,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasFiles && paths.length <= 5) ...[
          const SizedBox(height: 6),
          for (final path in paths)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.image_outlined,
                    size: 13,
                    color: AppColors.textMedium,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _basename(path),
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (hasFiles && paths.length > 5) ...[
          const SizedBox(height: 4),
          Text('${paths.length} images selected', style: AppTextStyles.caption),
        ],
      ],
    );
  }

  static String _basename(String path) {
    final sep = path.contains('/') ? '/' : r'\';
    return path.split(sep).last;
  }
}

class _ModelSelector extends StatelessWidget {
  final BgRemovalModel value;
  final ValueChanged<BgRemovalModel> onChanged;

  const _ModelSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BgRemovalModel.values.map((m) {
        final selected = m == value;
        return GestureDetector(
          onTap: () => onChanged(m),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySurface : AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.6)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.displayName,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textHigh,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(m.sizeLabel, style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 2),
                Text(m.description, style: AppTextStyles.caption),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OutputDirRow extends StatelessWidget {
  final String path;
  final ValueChanged<String> onChanged;

  const _OutputDirRow({required this.path, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Output Folder', style: AppTextStyles.labelMedium),
              const SizedBox(height: 4),
              Text(
                path.isEmpty ? 'No folder selected' : path,
                style: AppTextStyles.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final dir = await getDirectoryPath(
              confirmButtonText: 'Select Output Folder',
            );
            if (dir != null) onChanged(dir);
          },
          icon: const Icon(Icons.folder_open_rounded, size: 16),
          label: const Text('Browse'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textMedium,
            side: const BorderSide(color: AppColors.border),
            textStyle: AppTextStyles.labelMedium,
          ),
        ),
      ],
    );
  }
}

class _AdvancedOptions extends StatelessWidget {
  final BgRemovalRequest request;
  final ValueChanged<BgRemovalRequest> onChanged;

  const _AdvancedOptions({required this.request, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alpha Matting',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textHigh,
                      ),
                    ),
                    Text(
                      'Improves fine hair and fur edges. Slower.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Switch(
                value: request.alphaMatting,
                onChanged: (v) => onChanged(request.copyWith(alphaMatting: v)),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (request.alphaMatting) ...[
            const SizedBox(height: 12),
            _SliderRow(
              label: 'Foreground Threshold',
              value: request.alphaMattingFgThreshold.toDouble(),
              min: 200,
              max: 255,
              onChanged: (v) => onChanged(
                request.copyWith(alphaMattingFgThreshold: v.round()),
              ),
            ),
            const SizedBox(height: 8),
            _SliderRow(
              label: 'Background Threshold',
              value: request.alphaMattingBgThreshold.toDouble(),
              min: 0,
              max: 50,
              onChanged: (v) => onChanged(
                request.copyWith(alphaMattingBgThreshold: v.round()),
              ),
            ),
            const SizedBox(height: 8),
            _SliderRow(
              label: 'Erode Size',
              value: request.alphaMattingErodeSize.toDouble(),
              min: 0,
              max: 40,
              onChanged: (v) =>
                  onChanged(request.copyWith(alphaMattingErodeSize: v.round())),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post-process Mask',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textHigh,
                      ),
                    ),
                    Text(
                      'Cleans up mask artefacts.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Switch(
                value: request.postProcessMask,
                onChanged: (v) =>
                    onChanged(request.copyWith(postProcessMask: v)),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => onChanged(
                BgRemovalRequest(
                  model: request.model,
                  outputDirectory: request.outputDirectory,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMedium,
                textStyle: AppTextStyles.labelSmall,
              ),
              child: const Text('Reset to Defaults'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 160, child: Text(label, style: AppTextStyles.caption)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.round().toString(),
            style: AppTextStyles.caption,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
