import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../local_db/models/enums.dart';
import '../../../local_db/models/itinerary_stop_model.dart';

class StopMarkerWidget extends StatelessWidget {
  final ItineraryStopModel stop;
  final VoidCallback? onTap;

  const StopMarkerWidget({
    super.key,
    required this.stop,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.stopTypeColor(stop.type.name);

    if (stop.type == StopType.waypoint) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: AppDimensions.mapWaypointMarkerSize,
          height: AppDimensions.mapWaypointMarkerSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppDimensions.mapMarkerSize,
            height: AppDimensions.mapMarkerSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                stop.type.icon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
