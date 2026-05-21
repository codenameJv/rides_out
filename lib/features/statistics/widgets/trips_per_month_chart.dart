import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';

class TripsPerMonthChart extends StatelessWidget {
  final Map<String, int> tripsPerMonth;

  const TripsPerMonthChart({super.key, required this.tripsPerMonth});

  @override
  Widget build(BuildContext context) {
    final maxCount =
        tripsPerMonth.values.fold<int>(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trips Per Month', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppDimensions.paddingMD),
            ...tripsPerMonth.entries.map((entry) {
              final label = _formatMonth(entry.key);
              final fraction = maxCount > 0 ? entry.value / maxCount : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(label, style: AppTextStyles.bodySmall),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 16,
                              width: (constraints.maxWidth * fraction)
                                  .clamp(entry.value > 0 ? 8.0 : 0.0,
                                      constraints.maxWidth),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 20,
                      child: Text(
                        '${entry.value}',
                        style: AppTextStyles.bodySmall,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatMonth(String key) {
    final parts = key.split('-');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final monthIdx = int.parse(parts[1]) - 1;
    return months[monthIdx];
  }
}
