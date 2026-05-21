import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../providers/fuel_calculator_provider.dart';

class FuelEstimateCard extends StatelessWidget {
  final FuelEstimate estimate;

  const FuelEstimateCard({super.key, required this.estimate});

  @override
  Widget build(BuildContext context) {
    final unitLabel =
        estimate.fuelUnit == FuelPriceUnit.liter ? 'liters' : 'gallons';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trip Estimate', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppDimensions.paddingMD),
            _ResultRow(
              icon: Icons.straighten,
              label: 'Distance',
              value:
                  '${estimate.distanceMiles.toStringAsFixed(1)} mi / ${estimate.distanceKm.toStringAsFixed(1)} km',
            ),
            const SizedBox(height: AppDimensions.paddingSM),
            _ResultRow(
              icon: Icons.local_gas_station,
              label: 'Fuel Needed',
              value: '${estimate.fuelNeeded.toStringAsFixed(1)} $unitLabel',
            ),
            const SizedBox(height: AppDimensions.paddingSM),
            _ResultRow(
              icon: Icons.attach_money,
              label: 'Estimated Cost',
              value: CurrencyFormatter.format(estimate.totalCost),
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: 20, color: highlight ? AppColors.primary : AppColors.textSecondary),
        const SizedBox(width: AppDimensions.paddingSM),
        Text(label, style: AppTextStyles.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: highlight
              ? AppTextStyles.titleMedium
                  .copyWith(color: AppColors.primary)
              : AppTextStyles.titleMedium,
        ),
      ],
    );
  }
}
