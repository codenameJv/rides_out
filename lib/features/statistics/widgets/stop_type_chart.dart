import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../local_db/models/enums.dart';

class StopTypeChart extends StatelessWidget {
  final Map<StopType, int> stopTypeCounts;

  const StopTypeChart({super.key, required this.stopTypeCounts});

  @override
  Widget build(BuildContext context) {
    if (stopTypeCounts.isEmpty) return const SizedBox.shrink();

    final sorted = stopTypeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = sorted.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stop Types', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppDimensions.paddingMD),
            ...sorted.map((entry) {
              final fraction = maxCount > 0 ? entry.value / maxCount : 0.0;
              final color = AppColors.stopTypeColor(entry.key.name);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(entry.key.icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 72,
                      child:
                          Text(entry.key.label, style: AppTextStyles.bodySmall),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 16,
                              width: (constraints.maxWidth * fraction)
                                  .clamp(8.0, constraints.maxWidth),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
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
}
