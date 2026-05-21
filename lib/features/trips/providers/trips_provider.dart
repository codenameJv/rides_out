import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/utils/id_generator.dart';
import '../../../local_db/models/trip_model.dart';
import '../../../local_db/models/enums.dart';
import '../../../local_db/models/itinerary_stop_model.dart';
import '../../../local_db/models/checklist_item_model.dart';
import '../../../local_db/models/stop_task_model.dart';

final tripsProvider =
    StateNotifierProvider<TripsNotifier, List<TripModel>>((ref) {
  return TripsNotifier();
});

// Derived providers
final upcomingTripsProvider = Provider<List<TripModel>>((ref) {
  final trips = ref.watch(tripsProvider);
  final now = DateTime.now();
  return trips
      .where((t) =>
          t.status != TripStatus.completed && t.startDate.isAfter(now))
      .toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
});

final recentTripsProvider = Provider<List<TripModel>>((ref) {
  final trips = ref.watch(tripsProvider);
  return trips.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
});

final tripByIdProvider = Provider.family<TripModel?, String>((ref, id) {
  final trips = ref.watch(tripsProvider);
  try {
    return trips.firstWhere((t) => t.id == id);
  } catch (_) {
    return null;
  }
});

class TripsNotifier extends StateNotifier<List<TripModel>> {
  final _box = HiveService.tripsBox;

  TripsNotifier() : super([]) {
    _loadTrips();
  }

  void _loadTrips() {
    state = _box.values.toList();
  }

  Future<TripModel> createTrip({
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    double budget = 0,
  }) async {
    final trip = TripModel(
      id: IdGenerator.generate(),
      name: name,
      description: description,
      startDate: startDate,
      endDate: endDate,
      budget: budget,
    );
    await _box.put(trip.id, trip);
    state = _box.values.toList();
    return trip;
  }

  Future<void> updateTrip(TripModel trip) async {
    trip.updatedAt = DateTime.now();
    await _box.put(trip.id, trip);
    state = _box.values.toList();
  }

  Future<void> deleteTrip(String id) async {
    await _box.delete(id);
    state = _box.values.toList();
  }

  TripModel? getTrip(String id) {
    try {
      return state.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<TripModel?> duplicateTrip(String tripId) async {
    final original = getTrip(tripId);
    if (original == null) return null;

    final now = DateTime.now();
    final duration = original.endDate.difference(original.startDate);

    final newStops = original.stops.map((stop) {
      final newTasks = stop.tasks
          .map((t) => StopTaskModel(
                id: IdGenerator.generate(),
                label: t.label,
              ))
          .toList();
      return ItineraryStopModel(
        id: IdGenerator.generate(),
        name: stop.name,
        description: stop.description,
        type: stop.type,
        location: stop.location,
        order: stop.order,
        tasks: newTasks,
      );
    }).toList();

    final newChecklist = original.checklist
        .map((item) => ChecklistItemModel(
              id: IdGenerator.generate(),
              label: item.label,
              category: item.category,
            ))
        .toList();

    final copy = TripModel(
      id: IdGenerator.generate(),
      name: 'Copy of ${original.name}',
      description: original.description,
      status: TripStatus.planning,
      startDate: now,
      endDate: now.add(duration),
      budget: original.budget,
      stops: newStops,
      checklist: newChecklist,
    );

    await _box.put(copy.id, copy);
    state = _box.values.toList();
    return copy;
  }
}
