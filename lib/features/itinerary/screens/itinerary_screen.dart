import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../local_db/models/itinerary_stop_model.dart';
import '../providers/itinerary_provider.dart';
import '../widgets/timeline_widget.dart';

class ItineraryScreen extends ConsumerStatefulWidget {
  final String tripId;

  const ItineraryScreen({super.key, required this.tripId});

  @override
  ConsumerState<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends ConsumerState<ItineraryScreen> {
  List<ItineraryStopModel>? _localStops;

  @override
  Widget build(BuildContext context) {
    final allStops = ref.watch(itineraryProvider(widget.tripId));
    final providerStops =
        allStops.where((s) => !s.type.isShapeOnly).toList();
    final actions = ref.read(itineraryActionsProvider(widget.tripId));

    // Use local state if available (during reorder), otherwise use provider
    final stops = _localStops ?? providerStops;

    // Sync local state back to provider when provider updates
    if (_localStops != null &&
        _localStops!.length == providerStops.length &&
        providerStops.isNotEmpty) {
      // Provider has caught up — clear local override
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _localStops = null);
      });
    }

    if (stops.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.route,
        title: 'No stops yet',
        subtitle: 'Add your first stop to start building your route.',
        action: ElevatedButton.icon(
          onPressed: () => context.push('/trip/${widget.tripId}/stop/new'),
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
              context.push('/trip/${widget.tripId}/stop/${stop.id}'),
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
          onReorder: (oldIndex, newIndex) {
            // Apply reorder locally for immediate visual feedback
            if (newIndex > oldIndex) newIndex--;
            final reordered = List<ItineraryStopModel>.from(stops);
            final item = reordered.removeAt(oldIndex);
            reordered.insert(newIndex, item);
            setState(() => _localStops = reordered);

            // Persist via provider (async)
            actions.reorderStopById(item.id, newIndex);
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_stop',
            onPressed: () => context.push('/trip/${widget.tripId}/stop/new'),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
