import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../local_db/models/itinerary_stop_model.dart';
import 'stop_card.dart';
import 'timeline_connector.dart';

class TimelineWidget extends StatelessWidget {
  final List<ItineraryStopModel> stops;
  final void Function(ItineraryStopModel stop)? onStopTap;
  final void Function(ItineraryStopModel stop)? onStopDelete;
  final void Function(String stopId, String taskId)? onToggleTask;
  final void Function(String stopId)? onToggleDone;
  final void Function(int oldIndex, int newIndex)? onReorder;

  const TimelineWidget({
    super.key,
    required this.stops,
    this.onStopTap,
    this.onStopDelete,
    this.onToggleTask,
    this.onToggleDone,
    this.onReorder,
  });

  Widget _buildItem(int index) {
    final stop = stops[index];
    return IntrinsicHeight(
      key: ValueKey(stop.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onReorder != null)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Center(
                  child: Icon(
                    Icons.drag_handle,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                ),
              ),
            ),
          TimelineConnector(
            type: stop.type,
            isFirst: index == 0,
            isLast: index == stops.length - 1,
          ),
          Expanded(
            child: StopCard(
              stop: stop,
              onTap: onStopTap != null ? () => onStopTap!(stop) : null,
              onDelete:
                  onStopDelete != null ? () => onStopDelete!(stop) : null,
              onToggleTask: onToggleTask != null
                  ? (taskId) => onToggleTask!(stop.id, taskId)
                  : null,
              onToggleDone: onToggleDone != null
                  ? () => onToggleDone!(stop.id)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (onReorder != null) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.only(
          top: AppDimensions.paddingSM,
          bottom: 80,
        ),
        itemCount: stops.length,
        onReorder: onReorder!,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Material(
              elevation: 4,
              color: Colors.transparent,
              child: child,
            ),
            child: child,
          );
        },
        itemBuilder: (context, index) => _buildItem(index),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: AppDimensions.paddingSM,
        bottom: 80,
      ),
      itemCount: stops.length,
      itemBuilder: (context, index) => _buildItem(index),
    );
  }
}
