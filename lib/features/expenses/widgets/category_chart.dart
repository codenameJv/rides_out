import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../local_db/models/enums.dart';

class CategoryChart extends StatelessWidget {
  final Map<ExpenseCategory, double> data;
  final double total;

  const CategoryChart({
    super.key,
    required this.data,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By Category', style: AppTextStyles.titleMedium),
            const SizedBox(height: 12),
            ...sorted.map((entry) {
              final pct = total > 0 ? entry.value / total : 0.0;
              final color =
                  AppColors.expenseCategoryColor(entry.key.name);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        entry.key.label,
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: AlwaysStoppedAnimation(color),
                          minHeight: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 65,
                      child: Text(
                        CurrencyFormatter.format(entry.value),
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
