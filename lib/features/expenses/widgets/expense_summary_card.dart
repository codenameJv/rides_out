import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/currency_formatter.dart';

class ExpenseSummaryCard extends StatelessWidget {
  final double totalSpent;
  final double budget;

  const ExpenseSummaryCard({
    super.key,
    required this.totalSpent,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = budget > 0;
    final remaining = budget - totalSpent;
    final progress = hasBudget ? CurrencyFormatter.percentSpent(budget, totalSpent) : 0.0;

    return Card(
      margin: const EdgeInsets.all(AppDimensions.paddingMD),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Spent', style: AppTextStyles.bodySmall),
                    Text(
                      CurrencyFormatter.format(totalSpent),
                      style: AppTextStyles.headlineMedium,
                    ),
                  ],
                ),
                if (hasBudget)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Remaining', style: AppTextStyles.bodySmall),
                      Text(
                        CurrencyFormatter.remaining(budget, totalSpent),
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: remaining >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (hasBudget) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 0.9 ? AppColors.error : AppColors.primary,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).round()}% of ${CurrencyFormatter.format(budget)} budget',
                style: AppTextStyles.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
