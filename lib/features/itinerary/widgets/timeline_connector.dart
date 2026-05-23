import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../local_db/models/enums.dart';

class TimelineConnector extends StatelessWidget {
  final StopType type;
  final bool isFirst;
  final bool isLast;

  const TimelineConnector({
    super.key,
    required this.type,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.stopTypeColor(type.name);
    return SizedBox(
      width: AppDimensions.paddingXL + 8,
      child: Column(
        children: [
          if (!isFirst)
            Container(
              width: 2,
              height: 20,
              color: AppColors.surfaceHighlight,
            ),
          Container(
            width: (type == StopType.waypoint || type == StopType.shapePoint) ? 8 : 12,
            height: (type == StopType.waypoint || type == StopType.shapePoint) ? 8 : 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: (type == StopType.waypoint || type == StopType.shapePoint) ? 2 : 3,
              ),
            ),
          ),
          if (!isLast)
            Expanded(
              child: Container(
                width: 2,
                color: AppColors.surfaceHighlight,
              ),
            ),
        ],
      ),
    );
  }
}
