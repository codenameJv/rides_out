import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';

class SpeedLegend extends StatelessWidget {
  const SpeedLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingSM,
        vertical: AppDimensions.paddingXS,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '0',
            style: TextStyle(fontSize: 10, color: AppColors.textHint),
          ),
          const SizedBox(width: 4),
          Container(
            width: 120,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [
                  AppColors.success,
                  AppColors.warning,
                  AppColors.error,
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '80+ km/h',
            style: TextStyle(fontSize: 10, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}
