import 'package:flutter/material.dart';
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

  const TimelineWidget({
    super.key,
    required this.stops,
    this.onStopTap,
    this.onStopDelete,
    this.onToggleTask,
    this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(
        top: AppDimensions.paddingSM,
        bottom: 80,
      ),
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final stop = stops[index];
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
      },
    );
  }
}
