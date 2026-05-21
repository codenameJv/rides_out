import 'dart:async';

import 'package:geolocator/geolocator.dart';
import '../../local_db/models/route_point_model.dart';

class RideTrackingService {
  RideTrackingService._();
  static final RideTrackingService instance = RideTrackingService._();

  StreamSubscription<Position>? _positionSub;
  final List<RoutePointModel> _points = [];
  bool _isTracking = false;
  bool _isPaused = false;

  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  List<RoutePointModel> get points => List.unmodifiable(_points);

  /// Check and request location permissions. Returns true if granted.
  Future<bool> ensurePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Start tracking. Calls [onPoint] for each new point.
  Future<void> start({void Function(RoutePointModel point)? onPoint}) async {
    if (_isTracking) return;

    _points.clear();
    _isTracking = true;
    _isPaused = false;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
      if (_isPaused) return;
      final point = RoutePointModel(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );
      _points.add(point);
      onPoint?.call(point);
    });
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  /// Stop tracking and return all recorded points.
  List<RoutePointModel> stop() {
    _positionSub?.cancel();
    _positionSub = null;
    _isTracking = false;
    _isPaused = false;
    return List.from(_points);
  }
}
