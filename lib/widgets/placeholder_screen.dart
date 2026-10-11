import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.displayMedium,
            ).animate().fadeIn(duration: 200.ms),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMedium,
              ),
            ).animate().fadeIn(delay: 50.ms, duration: 200.ms),
            const SizedBox(height: 48),
            Expanded(
              child: Center(
                child:
                    Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                icon,
                                size: 40,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Coming Soon',
                              style: AppTextStyles.headingMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This feature is not yet available.',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(delay: 100.ms)
                        .scale(begin: const Offset(0.95, 0.95)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
