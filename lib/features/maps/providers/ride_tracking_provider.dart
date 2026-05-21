import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/ride_tracking_service.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../../local_db/models/route_point_model.dart';
import '../../trips/providers/trips_provider.dart';

class RideTrackingState {
  final bool isTracking;
  final bool isPaused;
  final String? tripId;
  final List<RoutePointModel> points;
  final DateTime? startTime;
  final Duration elapsedDuration;
  final double distanceKm;

  const RideTrackingState({
    this.isTracking = false,
    this.isPaused = false,
    this.tripId,
    this.points = const [],
    this.startTime,
    this.elapsedDuration = Duration.zero,
    this.distanceKm = 0,
  });

  RideTrackingState copyWith({
    bool? isTracking,
    bool? isPaused,
    String? tripId,
    List<RoutePointModel>? points,
    DateTime? startTime,
    Duration? elapsedDuration,
    double? distanceKm,
  }) {
    return RideTrackingState(
      isTracking: isTracking ?? this.isTracking,
      isPaused: isPaused ?? this.isPaused,
      tripId: tripId ?? this.tripId,
      points: points ?? this.points,
      startTime: startTime ?? this.startTime,
      elapsedDuration: elapsedDuration ?? this.elapsedDuration,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}

class RideTrackingNotifier extends StateNotifier<RideTrackingState> {
  final Ref _ref;
  RideTrackingNotifier(this._ref) : super(const RideTrackingState());

  final _service = RideTrackingService.instance;

  Future<bool> startTracking(String tripId) async {
    final hasPermission = await _service.ensurePermission();
    if (!hasPermission) return false;

    state = RideTrackingState(
      isTracking: true,
      tripId: tripId,
      startTime: DateTime.now(),
    );

    await _service.start(onPoint: (point) {
      final newPoints = [...state.points, point];
      double dist = 0;
      if (newPoints.length >= 2) {
        final prev = newPoints[newPoints.length - 2];
        dist = state.distanceKm +
            DistanceCalculator.distanceKm(
              prev.latitude,
              prev.longitude,
              point.latitude,
              point.longitude,
            );
      }
      state = state.copyWith(
        points: newPoints,
        distanceKm: dist,
        elapsedDuration: state.startTime != null
            ? DateTime.now().difference(state.startTime!)
            : Duration.zero,
      );
    });

    return true;
  }

  void pauseTracking() {
    _service.pause();
    state = state.copyWith(
      isPaused: true,
      elapsedDuration: state.startTime != null
          ? DateTime.now().difference(state.startTime!)
          : state.elapsedDuration,
    );
  }

  void updateElapsed() {
    if (state.isTracking && !state.isPaused && state.startTime != null) {
      state = state.copyWith(
        elapsedDuration: DateTime.now().difference(state.startTime!),
      );
    }
  }

  void resumeTracking() {
    _service.resume();
    state = state.copyWith(isPaused: false);
  }

  /// Stop tracking and save the recorded route to the trip.
  Future<void> stopAndSave() async {
    final points = _service.stop();
    final tripId = state.tripId;

    if (tripId != null && points.isNotEmpty) {
      final notifier = _ref.read(tripsProvider.notifier);
      final trip = notifier.getTrip(tripId);
      if (trip != null) {
        final updated = trip.copyWith(recordedRoute: points);
        await notifier.updateTrip(updated);
      }
    }

    state = const RideTrackingState();
  }

  /// Stop tracking without saving.
  void cancel() {
    _service.stop();
    state = const RideTrackingState();
  }
}

final rideTrackingProvider =
    StateNotifierProvider<RideTrackingNotifier, RideTrackingState>((ref) {
  return RideTrackingNotifier(ref);
});
