import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../../local_db/models/enums.dart';
import '../providers/statistics_provider.dart';
import '../widgets/stat_summary_card.dart';
import '../widgets/trips_per_month_chart.dart';
import '../widgets/stop_type_chart.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(tripStatisticsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Statistics')),
      body: stats.totalTrips == 0
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart,
                      size: 64, color: AppColors.textHint),
                  const SizedBox(height: AppDimensions.paddingMD),
                  Text(
                    'No trips yet',
                    style: AppTextStyles.headlineSmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppDimensions.paddingSM),
                  Text(
                    'Create some trips to see your stats!',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textHint),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              children: [
                // Summary row
                Row(
                  children: [
                    Expanded(
                      child: StatSummaryCard(
                        icon: Icons.two_wheeler,
                        value: '${stats.totalTrips}',
                        label: 'Trips',
                      ),
                    ),
                    const SizedBox(width: AppDimensions.paddingSM),
                    Expanded(
                      child: StatSummaryCard(
                        icon: Icons.straighten,
                        value: DistanceCalculator.formatDistance(
                            stats.totalKm),
                        label: 'Kilometers',
                      ),
                    ),
                    const SizedBox(width: AppDimensions.paddingSM),
                    Expanded(
                      child: StatSummaryCard(
                        icon: Icons.attach_money,
                        value: CurrencyFormatter.compact(stats.totalSpent),
                        label: 'Spent',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.paddingMD),

                // Trips by status
                if (stats.tripsByStatus.isNotEmpty)
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(AppDimensions.paddingMD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('By Status',
                              style: AppTextStyles.headlineSmall),
                          const SizedBox(height: AppDimensions.paddingSM),
                          Wrap(
                            spacing: AppDimensions.paddingSM,
                            runSpacing: AppDimensions.paddingSM,
                            children: stats.tripsByStatus.entries
                                .map((e) => Chip(
                                      avatar: CircleAvatar(
                                        backgroundColor:
                                            _statusColor(e.key),
                                        child: Text(
                                          '${e.value}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      label: Text(e.key.label),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: AppDimensions.paddingMD),

                // Highlights
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(AppDimensions.paddingMD),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Highlights',
                            style: AppTextStyles.headlineSmall),
                        const SizedBox(height: AppDimensions.paddingSM),
                        _HighlightRow(
                          icon: Icons.schedule,
                          label: 'Avg Trip Duration',
                          value:
                              '${stats.averageDurationDays.toStringAsFixed(1)} days',
                        ),
                        if (stats.mostExpensiveTrip != null) ...[
                          const SizedBox(height: AppDimensions.paddingSM),
                          _HighlightRow(
                            icon: Icons.attach_money,
                            label: 'Most Expensive',
                            value:
                                '${stats.mostExpensiveTrip!.name} (${CurrencyFormatter.compact(stats.mostExpensiveTrip!.totalExpenses)})',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.paddingMD),

                // Stop type chart
                if (stats.stopTypeCounts.isNotEmpty)
                  StopTypeChart(stopTypeCounts: stats.stopTypeCounts),

                const SizedBox(height: AppDimensions.paddingMD),

                // Trips per month
                if (stats.tripsPerMonth.isNotEmpty)
                  TripsPerMonthChart(tripsPerMonth: stats.tripsPerMonth),

                const SizedBox(height: AppDimensions.paddingMD),

                // Category spending
                if (stats.categorySpending.isNotEmpty)
                  _CategorySpendingCard(
                      spending: stats.categorySpending),

                const SizedBox(height: AppDimensions.paddingXL),
              ],
            ),
    );
  }

  Color _statusColor(TripStatus status) {
    switch (status) {
      case TripStatus.planning:
        return AppColors.info;
      case TripStatus.upcoming:
        return AppColors.warning;
      case TripStatus.active:
        return AppColors.success;
      case TripStatus.completed:
        return AppColors.textSecondary;
    }
  }
}

class _HighlightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HighlightRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: AppDimensions.paddingSM),
        Text(label, style: AppTextStyles.bodyMedium),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CategorySpendingCard extends StatelessWidget {
  final Map<ExpenseCategory, double> spending;

  const _CategorySpendingCard({required this.spending});

  @override
  Widget build(BuildContext context) {
    final sorted = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxAmount = sorted.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending by Category',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppDimensions.paddingMD),
            ...sorted.map((entry) {
              final fraction =
                  maxAmount > 0 ? entry.value / maxAmount : 0.0;
              final color =
                  AppColors.expenseCategoryColor(entry.key.name);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(entry.key.label,
                          style: AppTextStyles.bodySmall),
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
                      width: 72,
                      child: Text(
                        CurrencyFormatter.compact(entry.value),
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
