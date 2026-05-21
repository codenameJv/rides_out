import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../providers/itinerary_provider.dart';
import '../widgets/timeline_widget.dart';

class ItineraryScreen extends ConsumerWidget {
  final String tripId;

  const ItineraryScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops = ref.watch(itineraryProvider(tripId));
    final actions = ref.read(itineraryActionsProvider(tripId));

    if (stops.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.route,
        title: 'No stops yet',
        subtitle: 'Add your first stop to start building your route.',
        action: ElevatedButton.icon(
          onPressed: () => context.push('/trip/$tripId/stop/new'),
          icon: const Icon(Icons.add),
          label: const Text('Add Stop'),
        ),
      );
    }

    return Stack(
      children: [
        TimelineWidget(
          stops: stops,
          onStopTap: (stop) =>
              context.push('/trip/$tripId/stop/${stop.id}'),
          onStopDelete: (stop) async {
            final confirmed = await ConfirmDialog.show(
              context,
              title: 'Delete Stop',
              message: 'Delete "${stop.name}" from the itinerary?',
            );
            if (confirmed) {
              actions.deleteStop(stop.id);
            }
          },
          onToggleTask: (stopId, taskId) =>
              actions.toggleStopTask(stopId, taskId),
          onToggleDone: (stopId) => actions.toggleStopDone(stopId),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_stop',
            onPressed: () => context.push('/trip/$tripId/stop/new'),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
