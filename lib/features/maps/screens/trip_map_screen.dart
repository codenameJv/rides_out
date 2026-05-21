import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/nominatim_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../local_db/models/enums.dart';
import '../../../local_db/models/geo_point_model.dart';
import '../../itinerary/providers/itinerary_provider.dart';
import '../../trips/providers/trips_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../widgets/trip_map_view.dart';
import 'location_picker_screen.dart';

class TripMapScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripMapScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends ConsumerState<TripMapScreen> {
  bool _editMode = false;

  void _toggleEditMode() {
    setState(() => _editMode = !_editMode);
  }

  /// Find the best insertion order by locating the nearest route leg.
  int _findInsertionOrder(LatLng point, List<LatLng> stopPoints) {
    if (stopPoints.length < 2) return stopPoints.length;

    double minDist = double.infinity;
    int bestLeg = 0;

    for (int i = 0; i < stopPoints.length - 1; i++) {
      final d = _pointToSegmentDistance(point, stopPoints[i], stopPoints[i + 1]);
      if (d < minDist) {
        minDist = d;
        bestLeg = i;
      }
    }

    return bestLeg + 1;
  }

  double _pointToSegmentDistance(LatLng p, LatLng a, LatLng b) {
    final dx = b.latitude - a.latitude;
    final dy = b.longitude - a.longitude;
    if (dx == 0 && dy == 0) {
      return _haversine(p, a);
    }
    var t = ((p.latitude - a.latitude) * dx + (p.longitude - a.longitude) * dy) /
        (dx * dx + dy * dy);
    t = t.clamp(0.0, 1.0);
    final proj = LatLng(a.latitude + t * dx, a.longitude + t * dy);
    return _haversine(p, proj);
  }

  double _haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) *
            sin(dLon / 2) * sin(dLon / 2);
    return 2 * r * asin(sqrt(h));
  }

  double _toRad(double deg) => deg * pi / 180;

  Future<void> _addWaypoint(LatLng point) async {
    final stops = ref.read(itineraryProvider(widget.tripId));
    final stopPoints = stops
        .where((s) => s.location != null)
        .map((s) => LatLng(s.location!.latitude, s.location!.longitude))
        .toList();

    final insertOrder = _findInsertionOrder(point, stopPoints);

    final actions = ref.read(itineraryActionsProvider(widget.tripId));

    // Add immediately with default name
    final location = GeoPointModel(
      latitude: point.latitude,
      longitude: point.longitude,
    );

    await actions.addWaypoint(
      location: location,
      atOrder: insertOrder,
      name: 'Waypoint',
    );

    // Reverse geocode in background and update name
    NominatimService.reverse(point.latitude, point.longitude).then((name) {
      if (name != null && mounted) {
        final updatedStops = ref.read(itineraryProvider(widget.tripId));
        final waypoint = updatedStops.where(
          (s) =>
              s.type == StopType.waypoint &&
              s.location != null &&
              s.location!.latitude == point.latitude &&
              s.location!.longitude == point.longitude,
        ).firstOrNull;
        if (waypoint != null) {
          // Shorten the display name
          final short = name.split(',').first.trim();
          ref
              .read(itineraryActionsProvider(widget.tripId))
              .updateStop(waypoint.copyWith(name: short));
        }
      }
    });
  }

  Future<void> _searchAndAddWaypoint() async {
    final result = await Navigator.push<GeoPointModel>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null && mounted) {
      await _addWaypoint(LatLng(result.latitude, result.longitude));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripByIdProvider(widget.tripId));
    final stops = ref.watch(itineraryProvider(widget.tripId));
    final stopsWithLocation =
        stops.where((s) => s.location != null).toList();

    final waypointCount =
        stops.where((s) => s.type == StopType.waypoint).length;
    final regularStopCount = stopsWithLocation.length - waypointCount;

    // Calculate total distance
    final points = stopsWithLocation
        .map((s) => (s.location!.latitude, s.location!.longitude))
        .toList();
    final totalDist = DistanceCalculator.totalDistance(points);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(trip?.name ?? 'Map'),
        actions: [
          IconButton(
            icon: Icon(_editMode ? Icons.edit_off : Icons.edit_location_alt),
            tooltip: _editMode ? 'Exit edit mode' : 'Edit waypoints',
            color: _editMode ? AppColors.primary : null,
            onPressed: _toggleEditMode,
          ),
          if (stopsWithLocation.length >= 2)
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              tooltip: 'Play Replay',
              onPressed: () => context.go('/trip/${widget.tripId}/replay'),
            ),
          if (stopsWithLocation.length >= 2)
            IconButton(
              icon: const Icon(Icons.navigation),
              tooltip: 'Open in Maps',
              onPressed: () => _openInMaps(stopsWithLocation),
            ),
        ],
      ),
      floatingActionButton: _editMode
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: _searchAndAddWaypoint,
              child: const Icon(Icons.search, color: Colors.white),
            )
          : null,
      body: stopsWithLocation.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.map,
              title: 'No locations on map',
              subtitle: 'Add locations to your stops to see them on the map.',
            )
          : Column(
              children: [
                if (_editMode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingMD,
                      vertical: AppDimensions.paddingSM,
                    ),
                    color: AppColors.primary.withValues(alpha: 0.12),
                    child: Row(
                      children: [
                        const Icon(Icons.touch_app,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Tap the map to add waypoints',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMD,
                    vertical: AppDimensions.paddingSM,
                  ),
                  color: AppColors.surface,
                  child: Row(
                    children: [
                      if (trip != null && trip.hasRecordedRoute)
                        Container(
                          margin: const EdgeInsets.only(
                              right: AppDimensions.paddingSM),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.paddingSM,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSM),
                          ),
                          child: Text(
                            'Recorded route',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (totalDist > 0)
                        Container(
                          margin: const EdgeInsets.only(
                              right: AppDimensions.paddingSM),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.paddingSM,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textHint.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSM),
                          ),
                          child: Text(
                            'Estimated route',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                      if (totalDist > 0)
                        Text(
                          waypointCount > 0
                              ? '$regularStopCount stops + $waypointCount waypoints · ${DistanceCalculator.formatDistance(totalDist)} total'
                              : '${stopsWithLocation.length} stops · ${DistanceCalculator.formatDistance(totalDist)} total',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: TripMapView(
                    stops: stops,
                    recordedRoute:
                        trip != null && trip.hasRecordedRoute
                            ? trip.recordedRoute
                            : null,
                    onMapTap: _editMode ? _addWaypoint : null,
                  ),
                ),
              ],
            ),
    );
  }

  void _openInMaps(List stops) async {
    if (stops.length < 2) return;
    final first = stops.first;
    final last = stops.last;
    final origin =
        '${first.location!.latitude},${first.location!.longitude}';
    final dest = '${last.location!.latitude},${last.location!.longitude}';

    // Build waypoints from intermediate stops
    final waypoints = stops
        .sublist(1, stops.length - 1)
        .where((s) => s.location != null)
        .map((s) => '${s.location!.latitude},${s.location!.longitude}')
        .join('|');

    var url =
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dest';
    if (waypoints.isNotEmpty) {
      url += '&waypoints=$waypoints';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
