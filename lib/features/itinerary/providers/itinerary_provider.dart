import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/id_generator.dart';
import '../../../local_db/models/itinerary_stop_model.dart';
import '../../../local_db/models/stop_task_model.dart';
import '../../../local_db/models/enums.dart';
import '../../../local_db/models/geo_point_model.dart';
import '../../trips/providers/trips_provider.dart';

final itineraryProvider =
    Provider.family<List<ItineraryStopModel>, String>((ref, tripId) {
  final trip = ref.watch(tripByIdProvider(tripId));
  if (trip == null) return [];
  return List.from(trip.stops)..sort((a, b) => a.order.compareTo(b.order));
});

final itineraryActionsProvider =
    Provider.family<ItineraryActions, String>((ref, tripId) {
  return ItineraryActions(ref, tripId);
});

class ItineraryActions {
  final Ref _ref;
  final String _tripId;

  ItineraryActions(this._ref, this._tripId);

  Future<void> addStop({
    required String name,
    String? description,
    required StopType type,
    GeoPointModel? location,
    DateTime? arrivalTime,
    List<StopTaskModel>? tasks,
  }) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final stop = ItineraryStopModel(
      id: IdGenerator.generate(),
      name: name,
      description: description,
      type: type,
      location: location,
      arrivalTime: arrivalTime,
      order: trip.stops.length,
      tasks: tasks ?? [],
    );

    final updatedTrip = trip.copyWith(stops: [...trip.stops, stop]);
    await notifier.updateTrip(updatedTrip);
  }

  Future<void> updateStop(ItineraryStopModel updatedStop) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final index = trip.stops.indexWhere((s) => s.id == updatedStop.id);
    if (index == -1) return;

    final updatedStops = List<ItineraryStopModel>.from(trip.stops);
    updatedStops[index] = updatedStop;
    final updatedTrip = trip.copyWith(stops: updatedStops);
    await notifier.updateTrip(updatedTrip);
  }

  Future<void> deleteStop(String stopId) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final updatedStops = trip.stops.where((s) => s.id != stopId).toList();
    for (int i = 0; i < updatedStops.length; i++) {
      updatedStops[i] = updatedStops[i].copyWith(order: i);
    }
    final updatedTrip = trip.copyWith(stops: updatedStops);
    await notifier.updateTrip(updatedTrip);
  }

  Future<void> reorderStops(int oldIndex, int newIndex) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final stops = List<ItineraryStopModel>.from(trip.stops)
      ..sort((a, b) => a.order.compareTo(b.order));

    if (newIndex > oldIndex) newIndex--;
    final item = stops.removeAt(oldIndex);
    stops.insert(newIndex, item);

    for (int i = 0; i < stops.length; i++) {
      stops[i] = stops[i].copyWith(order: i);
    }
    final updatedTrip = trip.copyWith(stops: stops);
    await notifier.updateTrip(updatedTrip);
  }

  Future<void> addWaypoint({
    required GeoPointModel location,
    required int atOrder,
    String? name,
  }) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final updatedStops = List<ItineraryStopModel>.from(trip.stops);
    for (int i = 0; i < updatedStops.length; i++) {
      if (updatedStops[i].order >= atOrder) {
        updatedStops[i] = updatedStops[i].copyWith(order: updatedStops[i].order + 1);
      }
    }

    final waypoint = ItineraryStopModel(
      id: IdGenerator.generate(),
      name: name ?? 'Waypoint',
      type: StopType.waypoint,
      location: location,
      order: atOrder,
    );

    updatedStops.add(waypoint);
    final updatedTrip = trip.copyWith(stops: updatedStops);
    await notifier.updateTrip(updatedTrip);
  }

  Future<void> toggleStopDone(String stopId) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final stopIndex = trip.stops.indexWhere((s) => s.id == stopId);
    if (stopIndex == -1) return;

    final stop = trip.stops[stopIndex];
    final updatedStop = stop.copyWith(isDone: !stop.isDone);
    final updatedStops = List<ItineraryStopModel>.from(trip.stops);
    updatedStops[stopIndex] = updatedStop;
    final updatedTrip = trip.copyWith(stops: updatedStops);
    await notifier.updateTrip(updatedTrip);
  }

  Future<void> toggleStopTask(String stopId, String taskId) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final stopIndex = trip.stops.indexWhere((s) => s.id == stopId);
    if (stopIndex == -1) return;

    final stop = trip.stops[stopIndex];
    final updatedTasks = stop.tasks.map((t) {
      if (t.id == taskId) return t.copyWith(isChecked: !t.isChecked);
      return t;
    }).toList();

    final updatedStop = stop.copyWith(tasks: updatedTasks);
    final updatedStops = List<ItineraryStopModel>.from(trip.stops);
    updatedStops[stopIndex] = updatedStop;
    final updatedTrip = trip.copyWith(stops: updatedStops);
    await notifier.updateTrip(updatedTrip);
  }
}
