import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';

class ReplayControls extends StatelessWidget {
  final bool isPlaying;
  final double progress;
  final double speed;
  final String? fromStop;
  final String? toStop;
  final VoidCallback onPlayPause;
  final VoidCallback onRestart;
  final VoidCallback onSpeedToggle;

  const ReplayControls({
    super.key,
    required this.isPlaying,
    required this.progress,
    required this.speed,
    this.fromStop,
    this.toStop,
    required this.onPlayPause,
    required this.onRestart,
    required this.onSpeedToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.paddingMD),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMD,
        vertical: AppDimensions.paddingSM,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(
          color: AppColors.surfaceHighlight,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stop names row
          if (fromStop != null && toStop != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.paddingXS),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      fromStop!,
                      style: AppTextStyles.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingSM,
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      size: AppDimensions.iconSM,
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      toStop!,
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceHighlight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingSM),
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay),
                color: AppColors.textPrimary,
                iconSize: AppDimensions.iconMD,
                tooltip: 'Restart',
                onPressed: onRestart,
              ),
              const SizedBox(width: AppDimensions.paddingSM),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  color: Colors.white,
                  iconSize: AppDimensions.iconLG,
                  tooltip: isPlaying ? 'Pause' : 'Play',
                  onPressed: onPlayPause,
                ),
              ),
              const SizedBox(width: AppDimensions.paddingSM),
              TextButton(
                onPressed: onSpeedToggle,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingSM,
                  ),
                  minimumSize: const Size(48, 40),
                ),
                child: Text(
                  '${speed.toStringAsFixed(0)}x',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
