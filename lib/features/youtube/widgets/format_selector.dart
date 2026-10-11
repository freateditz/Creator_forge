import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/media_info.dart';

class FormatSelector extends StatelessWidget {
  final List<QualityOption> options;
  final QualityOption selected;
  final ValueChanged<QualityOption> onChanged;

  const FormatSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quality', style: AppTextStyles.headingSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (opt) => _QualityChip(
                  option: opt,
                  isSelected: opt.preset == selected.preset,
                  onTap: opt.available ? () => onChanged(opt) : null,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _QualityChip extends StatefulWidget {
  final QualityOption option;
  final bool isSelected;
  final VoidCallback? onTap;

  const _QualityChip({
    required this.option,
    required this.isSelected,
    this.onTap,
  });

  @override
  State<_QualityChip> createState() => _QualityChipState();
}

class _QualityChipState extends State<_QualityChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final available = widget.onTap != null;
    final isSelected = widget.isSelected;

    return MouseRegion(
      cursor: available
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onEnter: available ? (_) => setState(() => _hovered = true) : null,
      onExit: available ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primarySurface
                : _hovered
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
                const Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.option.label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: isSelected
                      ? AppColors.primary
                      : available
                      ? AppColors.textHigh
                      : AppColors.textDisabled,
                  decoration: available ? null : TextDecoration.lineThrough,
                ),
              ),
              if (!available) ...[
                const SizedBox(width: 6),
                Text(
                  'N/A',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
