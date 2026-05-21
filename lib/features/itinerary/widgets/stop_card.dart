import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/tile_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../local_db/models/enums.dart';
import '../../../local_db/models/itinerary_stop_model.dart';

class StopCard extends StatelessWidget {
  final ItineraryStopModel stop;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final void Function(String taskId)? onToggleTask;
  final VoidCallback? onToggleDone;

  const StopCard({
    super.key,
    required this.stop,
    this.onTap,
    this.onDelete,
    this.onToggleTask,
    this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.stopTypeColor(stop.type.name);

    if (stop.type == StopType.waypoint) {
      return Card(
        margin: const EdgeInsets.only(
          left: AppDimensions.paddingXL + 8,
          right: AppDimensions.paddingMD,
          bottom: AppDimensions.paddingXS,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingSM + 4,
            vertical: AppDimensions.paddingSM,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  stop.name,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: AppColors.textHint,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      );
    }

    final checkedCount = stop.tasks.where((t) => t.isChecked).length;
    final totalTasks = stop.tasks.length;

    return Card(
      margin: const EdgeInsets.only(
        left: AppDimensions.paddingXL + 8,
        right: AppDimensions.paddingMD,
        bottom: AppDimensions.paddingXS,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingSM + 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSM),
                    ),
                    child: Center(
                      child: Text(
                        stop.type.icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          style: AppTextStyles.titleMedium.copyWith(
                            decoration:
                                stop.isDone ? TextDecoration.lineThrough : null,
                            color: stop.isDone
                                ? AppColors.textHint
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (stop.arrivalTime != null)
                          Text(
                            '${DateFormatter.dayMonth(stop.arrivalTime!)} at ${DateFormatter.time(stop.arrivalTime!)}',
                            style: AppTextStyles.bodySmall,
                          ),
                        if (totalTasks > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  '$checkedCount/$totalTasks tasks done',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onToggleDone != null)
                    IconButton(
                      icon: Icon(
                        stop.isDone
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        size: 22,
                      ),
                      color: stop.isDone
                          ? AppColors.primary
                          : AppColors.textHint,
                      onPressed: onToggleDone,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: AppColors.textHint,
                      onPressed: onDelete,
                    ),
                ],
              ),
            ),
            if (totalTasks > 0)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.paddingSM + 4,
                  right: AppDimensions.paddingSM + 4,
                  bottom: AppDimensions.paddingSM,
                ),
                child: Column(
                  children: stop.tasks.map((task) {
                    return InkWell(
                      onTap: onToggleTask != null
                          ? () => onToggleTask!(task.id)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              task.isChecked
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 18,
                              color: task.isChecked
                                  ? AppColors.primary
                                  : AppColors.textHint,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                task.label,
                                style: AppTextStyles.bodySmall.copyWith(
                                  decoration: task.isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.isChecked
                                      ? AppColors.textHint
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (stop.location != null)
              SizedBox(
                height: 120,
                child: IgnorePointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        stop.location!.latitude,
                        stop.location!.longitude,
                      ),
                      initialZoom: 14,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: AppConstants.osmTileUrl,
                        userAgentPackageName: 'com.ridesout.app',
                        tileProvider: TileCacheService.tileProvider,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              stop.location!.latitude,
                              stop.location!.longitude,
                            ),
                            width: 30,
                            height: 30,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
