import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../local_db/models/trip_model.dart';

class TripCard extends StatelessWidget {
  final TripModel trip;
  final int index;

  const TripCard({super.key, required this.trip, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMD,
        vertical: AppDimensions.paddingXS + 2,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        onTap: () => context.push('/trip/${trip.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.name,
                      style: AppTextStyles.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusBadge(status: trip.status.label),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    DateFormatter.dateRange(trip.startDate, trip.endDate),
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.schedule, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    DateFormatter.tripDuration(trip.startDate, trip.endDate),
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TripStatsRow(trip: trip),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 80).ms, duration: 400.ms)
        .slideX(begin: 0.05, end: 0);
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
      ),
      child: Text(
        status,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class TripStatsRow extends StatelessWidget {
  final TripModel trip;
  const TripStatsRow({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stat(Icons.route, '${trip.stops.length} stops'),
        const SizedBox(width: 16),
        _stat(Icons.checklist, '${trip.checklistProgress}%'),
        const SizedBox(width: 16),
        _stat(Icons.attach_money, '₱${trip.totalExpenses.toStringAsFixed(0)}'),
      ],
    );
  }

  Widget _stat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
