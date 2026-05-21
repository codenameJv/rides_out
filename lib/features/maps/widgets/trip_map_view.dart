import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/osrm_service.dart';
import '../../../core/services/tile_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../local_db/models/enums.dart';
import '../../../local_db/models/itinerary_stop_model.dart';
import '../../../local_db/models/route_point_model.dart';
import 'stop_marker.dart';

class TripMapView extends StatefulWidget {
  final List<ItineraryStopModel> stops;
  final void Function(ItineraryStopModel stop)? onStopTap;
  final List<RoutePointModel>? recordedRoute;
  final void Function(LatLng point)? onMapTap;

  const TripMapView({
    super.key,
    required this.stops,
    this.onStopTap,
    this.recordedRoute,
    this.onMapTap,
  });

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView> {
  List<OsrmRoute>? _routeAlternatives;
  int _selectedRouteIndex = 0;

  bool get _hasRecordedRoute =>
      widget.recordedRoute != null && widget.recordedRoute!.isNotEmpty;

  List<LatLng> _stopPoints() {
    return widget.stops
        .where((s) => s.location != null)
        .map((s) => LatLng(s.location!.latitude, s.location!.longitude))
        .toList();
  }

  List<LatLng> _recordedLatLngs() {
    return widget.recordedRoute!
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    if (!_hasRecordedRoute) _fetchRoutes();
  }

  @override
  void didUpdateWidget(TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.stops, widget.stops)) {
      _routeAlternatives = null;
      _selectedRouteIndex = 0;
      if (!_hasRecordedRoute) _fetchRoutes();
    }
  }

  Future<void> _fetchRoutes() async {
    final points = _stopPoints();
    if (points.length < 2) return;

    // Fetch alternatives for each leg, then combine into full-route options
    final legAlts = await OsrmService.getRouteLegAlternatives(points);
    if (!mounted) return;

    final combined = OsrmService.buildCombinedAlternatives(legAlts);
    setState(() {
      _routeAlternatives = combined;
      _selectedRouteIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stopsWithLocation =
        widget.stops.where((s) => s.location != null).toList();
    final stopPts = _stopPoints();

    // Determine polyline points
    List<LatLng> primaryPolyline;
    if (_hasRecordedRoute) {
      primaryPolyline = _recordedLatLngs();
    } else if (_routeAlternatives != null &&
        _routeAlternatives!.isNotEmpty) {
      primaryPolyline = _routeAlternatives![_selectedRouteIndex].points;
    } else {
      primaryPolyline = stopPts;
    }

    // Determine all points for centering (include recorded route points)
    final allPoints = _hasRecordedRoute
        ? [..._recordedLatLngs(), ...stopPts]
        : stopPts;

    final center = allPoints.isNotEmpty
        ? LatLng(
            allPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
                allPoints.length,
            allPoints.map((p) => p.longitude).reduce((a, b) => a + b) /
                allPoints.length,
          )
        : LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

    final zoom =
        allPoints.isEmpty ? AppConstants.defaultMapZoom : _fitZoom(allPoints);

    // Build polyline layers
    final polylines = <Polyline>[];

    // Show alternative routes (faded) first
    if (!_hasRecordedRoute &&
        _routeAlternatives != null &&
        _routeAlternatives!.length >= 2) {
      for (int i = 0; i < _routeAlternatives!.length; i++) {
        if (i == _selectedRouteIndex) continue;
        final alt = _routeAlternatives![i];
        if (alt.points.length >= 2) {
          polylines.add(Polyline(
            points: alt.points,
            strokeWidth: AppDimensions.mapLineWidth,
            color: AppColors.textHint.withValues(alpha: 0.35),
          ));
        }
      }
    }

    // Selected / recorded route (bright)
    if (primaryPolyline.length >= 2) {
      polylines.add(Polyline(
        points: primaryPolyline,
        strokeWidth: AppDimensions.mapLineWidth,
        color: AppColors.primary.withValues(alpha: 0.8),
      ));
    }

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            onTap: widget.onMapTap != null
                ? (_, point) => widget.onMapTap!(point)
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate: AppConstants.osmTileUrl,
              userAgentPackageName: 'com.ridesout.app',
              tileProvider: TileCacheService.tileProvider,
            ),
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            CurrentLocationLayer(),
            MarkerLayer(
              markers: stopsWithLocation.map((stop) {
                final isWaypoint = stop.type == StopType.waypoint;
                final size = isWaypoint
                    ? AppDimensions.mapWaypointMarkerSize
                    : AppDimensions.mapMarkerSize;
                return Marker(
                  point: LatLng(
                      stop.location!.latitude, stop.location!.longitude),
                  width: size,
                  height: isWaypoint ? size : size + 8,
                  child: StopMarkerWidget(
                    stop: stop,
                    onTap: widget.onStopTap != null
                        ? () => widget.onStopTap!(stop)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution(AppConstants.osmAttribution),
              ],
            ),
          ],
        ),

        // Route selection chips (always show when routes are loaded, no recorded route)
        if (!_hasRecordedRoute &&
            _routeAlternatives != null &&
            _routeAlternatives!.isNotEmpty)
          Positioned(
            bottom: AppDimensions.paddingMD,
            left: AppDimensions.paddingMD,
            right: AppDimensions.paddingMD,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_routeAlternatives!.length, (i) {
                  final alt = _routeAlternatives![i];
                  final isSelected = i == _selectedRouteIndex;
                  final distMiles = alt.distanceMeters / 1609.34;
                  final label = distMiles > 0
                      ? 'Route ${i + 1} (${distMiles.toStringAsFixed(1)} mi)'
                      : 'Route ${i + 1}';
                  return Padding(
                    padding: EdgeInsets.only(
                        right: i < _routeAlternatives!.length - 1
                            ? AppDimensions.paddingSM
                            : 0),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedRouteIndex = i);
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }

  double _fitZoom(List<LatLng> points) {
    if (points.length < 2) return 12;
    double maxLat = -90, minLat = 90, maxLng = -180, minLng = 180;
    for (final p in points) {
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
      if (p.longitude < minLng) minLng = p.longitude;
    }
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    if (maxDiff < 0.01) return 14;
    if (maxDiff < 0.1) return 12;
    if (maxDiff < 0.5) return 10;
    if (maxDiff < 2) return 8;
    if (maxDiff < 5) return 6;
    return 5;
  }
}
