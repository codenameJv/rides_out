import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import '../../../core/constants/app_constants.dart';
import '../../../core/services/osrm_service.dart';
import '../../../core/services/tile_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../../core/utils/route_segment_utils.dart';
import '../../../local_db/models/enums.dart';
import '../../../local_db/models/itinerary_stop_model.dart';
import '../../../local_db/models/route_point_model.dart';
import 'compass_button.dart';
import 'stop_marker.dart';
import 'zoom_buttons.dart';

class TripMapView extends StatefulWidget {
  final List<ItineraryStopModel> stops;
  final void Function(ItineraryStopModel stop)? onStopTap;
  final List<RoutePointModel>? recordedRoute;
  final void Function(LatLng point)? onMapTap;
  final List<Marker>? poiMarkers;
  final bool shapeMode;
  final bool showSuggestedRoute;

  const TripMapView({
    super.key,
    required this.stops,
    this.onStopTap,
    this.recordedRoute,
    this.onMapTap,
    this.poiMarkers,
    this.shapeMode = false,
    this.showSuggestedRoute = true,
  });

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView> {
  final MapController _mapController = MapController();
  // Per-leg alternatives from OSRM (one list of OsrmRoute per sub-leg)
  List<List<OsrmRoute>> _legAlternatives = [];
  // Selected alternative index per sub-leg (default 0 = primary)
  List<int> _selectedLegIndices = [];
  // Polyline hit detection notifier
  final LayerHitNotifier<int> _polylineHitNotifier = ValueNotifier(null);
  // Timestamp of last polyline hit (prevents onMapTap from firing on same tap)
  DateTime? _lastPolylineHitTime;

  List<({LatLng midpoint, String label})> _legLabels = [];
  double _mapRotation = 0.0;
  StreamSubscription? _mapEventSub;
  // Maps each sub-leg index to a visual leg index (merging shape-point gaps)
  List<int> _subLegToVisualLeg = [];

  // Cached values to avoid recomputation in build
  List<Marker>? _cachedArrowMarkers;
  List<int>? _cachedArrowSelection;
  double? _cachedFitZoom;
  List<LatLng>? _cachedFitZoomPoints;

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
    _centerOnUserLocation();
    _mapEventSub = _mapController.mapEventStream.listen((event) {
      if (event is MapEventRotate || event is MapEventRotateEnd) {
        setState(() => _mapRotation = _mapController.camera.rotation * 3.14159265 / 180.0);
      }
    });
    _polylineHitNotifier.addListener(_onPolylineHit);
  }

  Future<void> _centerOnUserLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (!mounted) return;
      _mapController.move(LatLng(pos.latitude, pos.longitude), 13);
    } catch (_) {
      // Permission denied or timeout — keep default center
    }
  }

  @override
  void dispose() {
    _polylineHitNotifier.removeListener(_onPolylineHit);
    _polylineHitNotifier.dispose();
    _mapEventSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.stops, widget.stops) ||
        oldWidget.showSuggestedRoute != widget.showSuggestedRoute) {
      _legAlternatives = [];
      _selectedLegIndices = [];
      _legLabels = [];
      _subLegToVisualLeg = [];
      _cachedArrowMarkers = null;
      _cachedArrowSelection = null;
      _cachedFitZoom = null;
      _cachedFitZoomPoints = null;
      if (!_hasRecordedRoute) _fetchRoutes();
    }
  }

  Future<void> _fetchRoutes() async {
    final points = _stopPoints();
    if (points.length < 2) return;

    List<List<OsrmRoute>> legAlts;

    if (!widget.showSuggestedRoute) {
      // Straight-line legs (no OSRM)
      legAlts = <List<OsrmRoute>>[];
      for (int i = 0; i < points.length - 1; i++) {
        final dist = const Distance().as(LengthUnit.Meter, points[i], points[i + 1]);
        legAlts.add([
          OsrmRoute(
            points: [points[i], points[i + 1]],
            distanceMeters: dist,
            durationSeconds: 0,
          ),
        ]);
      }
    } else {
      legAlts = await OsrmService.getRouteLegAlternatives(points);
      if (!mounted) return;
    }

    // Build sub-leg-to-visual-leg mapping (merge legs between real stops)
    final stopsWithLoc = widget.stops.where((s) => s.location != null).toList();
    final mapping = <int>[];
    int visualLeg = 0;
    for (int i = 0; i < stopsWithLoc.length - 1; i++) {
      mapping.add(visualLeg);
      if (!stopsWithLoc[i + 1].type.isShapeOnly) visualLeg++;
    }

    setState(() {
      _legAlternatives = legAlts;
      _selectedLegIndices = List<int>.filled(legAlts.length, 0);
      _subLegToVisualLeg = mapping;
      _cachedArrowMarkers = null;
      _cachedArrowSelection = null;
      _recomputeLabels();
    });
  }

  /// Returns the selected polyline points for each sub-leg.
  List<List<LatLng>> _getSelectedLegs() {
    final result = <List<LatLng>>[];
    for (int i = 0; i < _legAlternatives.length; i++) {
      final alts = _legAlternatives[i];
      final sel = i < _selectedLegIndices.length ? _selectedLegIndices[i] : 0;
      result.add(alts[sel.clamp(0, alts.length - 1)].points);
    }
    return result;
  }

  /// Recomputes distance labels per visual leg based on current selection.
  void _recomputeLabels() {
    final points = _stopPoints();
    final vlCount = _visualLegCount();
    if (vlCount == 0) {
      _legLabels = [];
      return;
    }

    final mergedDistances = List<double>.filled(vlCount, 0);
    final mergedAllPoints = List<List<LatLng>>.generate(vlCount, (_) => []);
    for (int i = 0; i < _legAlternatives.length; i++) {
      final vl = i < _subLegToVisualLeg.length ? _subLegToVisualLeg[i] : 0;
      if (vl < vlCount) {
        final alts = _legAlternatives[i];
        final sel = i < _selectedLegIndices.length ? _selectedLegIndices[i] : 0;
        final route = alts[sel.clamp(0, alts.length - 1)];
        mergedDistances[vl] += route.distanceMeters;
        mergedAllPoints[vl].addAll(route.points);
      }
    }

    final labels = <({LatLng midpoint, String label})>[];
    for (int vl = 0; vl < vlCount; vl++) {
      final pts = mergedAllPoints[vl];
      final mid = pts.isNotEmpty ? pts[pts.length ~/ 2] : points.first;
      labels.add((
        midpoint: mid,
        label: DistanceCalculator.formatDistance(mergedDistances[vl] / 1000.0),
      ));
    }
    _legLabels = labels;
  }

  int _visualLegCount() {
    if (_subLegToVisualLeg.isEmpty) return 0;
    return _subLegToVisualLeg.last + 1;
  }

  /// Handles polyline tap to select an alternative route.
  void _onPolylineHit() {
    final result = _polylineHitNotifier.value;
    if (result == null || result.hitValues.isEmpty) return;

    final hitValue = result.hitValues.first;
    final subLeg = hitValue ~/ 100;
    final altIndex = hitValue % 100;

    if (subLeg >= 0 &&
        subLeg < _legAlternatives.length &&
        altIndex >= 0 &&
        altIndex < _legAlternatives[subLeg].length &&
        _selectedLegIndices[subLeg] != altIndex) {
      _lastPolylineHitTime = DateTime.now();
      setState(() {
        _selectedLegIndices[subLeg] = altIndex;
        _cachedArrowMarkers = null;
        _cachedArrowSelection = null;
        _recomputeLabels();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stopsWithLocation =
        widget.stops.where((s) => s.location != null).toList();
    final stopPts = _stopPoints();

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
        allPoints.isEmpty ? AppConstants.defaultMapZoom : _fitZoomCached(allPoints);

    // Build polyline layers
    final polylines = <Polyline<int>>[];
    final hasLegRoutes = !_hasRecordedRoute && _legAlternatives.isNotEmpty;
    // Enable polyline tapping in normal mode and shape mode (not edit mode)
    final enableHit = hasLegRoutes && (widget.onMapTap == null || widget.shapeMode);

    if (_hasRecordedRoute) {
      // Multi-segment rendering with distinct colors
      final segments =
          RouteSegmentUtils.splitIntoSegments(widget.recordedRoute!);
      for (int i = 0; i < segments.length; i++) {
        final segPts = segments[i]
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        if (segPts.length >= 2) {
          final color = AppColors
              .segmentColors[i % AppColors.segmentColors.length];
          polylines.add(Polyline<int>(
            points: segPts,
            strokeWidth: AppDimensions.mapLineWidth,
            color: color.withValues(alpha: 0.8),
          ));
        }
      }
    } else if (hasLegRoutes) {
      final selectedLegs = _getSelectedLegs();

      // Show non-selected alternatives as faded lines (rendered first, behind selected)
      for (int i = 0; i < _legAlternatives.length; i++) {
        final sel = i < _selectedLegIndices.length ? _selectedLegIndices[i] : 0;
        for (int altIdx = 0; altIdx < _legAlternatives[i].length; altIdx++) {
          if (altIdx == sel) continue;
          final alt = _legAlternatives[i][altIdx];
          if (alt.points.length >= 2) {
            polylines.add(Polyline<int>(
              points: alt.points,
              strokeWidth: AppDimensions.mapLineWidth - 1,
              color: AppColors.textHint.withValues(alpha: 0.3),
              hitValue: i * 100 + altIdx,
            ));
          }
        }
      }

      // Selected polylines per sub-leg (colored by visual leg)
      for (int i = 0; i < selectedLegs.length; i++) {
        if (selectedLegs[i].length >= 2) {
          final vl = i < _subLegToVisualLeg.length ? _subLegToVisualLeg[i] : i;
          final sel = i < _selectedLegIndices.length ? _selectedLegIndices[i] : 0;
          final color = AppColors
              .segmentColors[vl % AppColors.segmentColors.length];
          polylines.add(Polyline<int>(
            points: selectedLegs[i],
            strokeWidth: AppDimensions.mapLineWidth,
            color: color.withValues(alpha: 0.8),
            hitValue: i * 100 + sel,
          ));
        }
      }
    } else if (stopPts.length >= 2) {
      // Fallback: straight line between stops
      polylines.add(Polyline<int>(
        points: stopPts,
        strokeWidth: AppDimensions.mapLineWidth,
        color: AppColors.primary.withValues(alpha: 0.8),
      ));
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onTap: widget.onMapTap != null
                ? (_, point) {
                    // Skip if a polyline was just tapped (prevents double-handling)
                    if (_lastPolylineHitTime != null &&
                        DateTime.now().difference(_lastPolylineHitTime!) <
                            const Duration(milliseconds: 200)) {
                      return;
                    }
                    widget.onMapTap!(point);
                  }
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate: AppConstants.osmTileUrl,
              userAgentPackageName: 'com.ridesout.app',
              tileProvider: TileCacheService.tileProvider,
            ),
            if (polylines.isNotEmpty)
              PolylineLayer<int>(
                polylines: polylines,
                hitNotifier: enableHit ? _polylineHitNotifier : null,
                minimumHitbox: 15,
              ),
            // Direction arrows for per-leg routes (cached)
            if (hasLegRoutes)
              MarkerLayer(
                markers: _getArrowMarkers(),
              ),
            CurrentLocationLayer(),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 80,
                disableClusteringAtZoom: 15,
                markers: stopsWithLocation
                    .where((s) => widget.shapeMode || !s.type.isShapeOnly)
                    .map((stop) {
                  final isShapePoint = stop.type.isShapeOnly;
                  final isWaypoint = stop.type == StopType.waypoint;
                  final size = isShapePoint
                      ? AppDimensions.mapShapePointMarkerSize
                      : isWaypoint
                          ? AppDimensions.mapWaypointMarkerSize
                          : AppDimensions.mapMarkerSize;
                  return Marker(
                    point: LatLng(
                        stop.location!.latitude, stop.location!.longitude),
                    width: size,
                    height: (isWaypoint || isShapePoint) ? size : size + 8,
                    child: StopMarkerWidget(
                      stop: stop,
                      onTap: widget.onStopTap != null
                          ? () => widget.onStopTap!(stop)
                          : null,
                    ),
                  );
                }).toList(),
                builder: (context, markers) {
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '${markers.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // POI markers
            if (widget.poiMarkers != null && widget.poiMarkers!.isNotEmpty)
              MarkerLayer(markers: widget.poiMarkers!),
            // Distance labels between stops
            if (_legLabels.isNotEmpty && !_hasRecordedRoute)
              MarkerLayer(
                markers: _legLabels.map((leg) {
                  return Marker(
                    point: leg.midpoint,
                    width: 70,
                    height: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        leg.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
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

        // Compass + Zoom buttons
        Positioned(
          top: AppDimensions.paddingMD,
          right: AppDimensions.paddingMD,
          child: Column(
            children: [
              CompassButton(
                mapController: _mapController,
                rotation: _mapRotation,
              ),
              const SizedBox(height: 8),
              ZoomButtons(
                onZoomIn: () {
                  final cam = _mapController.camera;
                  _mapController.move(cam.center, (cam.zoom + 1).clamp(3, 18));
                },
                onZoomOut: () {
                  final cam = _mapController.camera;
                  _mapController.move(cam.center, (cam.zoom - 1).clamp(3, 18));
                },
              ),
            ],
          ),
        ),

      ],
    );
  }

  List<Marker> _getArrowMarkers() {
    if (_cachedArrowMarkers != null &&
        listEquals(_cachedArrowSelection, _selectedLegIndices)) {
      return _cachedArrowMarkers!;
    }
    final markers = <Marker>[];
    final legs = _getSelectedLegs();
    for (int i = 0; i < legs.length; i++) {
      markers.addAll(_buildArrowMarkers(
        legs[i],
        AppColors.segmentColors[
            (i < _subLegToVisualLeg.length ? _subLegToVisualLeg[i] : i) %
                AppColors.segmentColors.length],
      ));
    }
    _cachedArrowMarkers = markers;
    _cachedArrowSelection = List<int>.from(_selectedLegIndices);
    return markers;
  }

  List<Marker> _buildArrowMarkers(List<LatLng> points, Color color) {
    if (points.length < 2) return [];
    final markers = <Marker>[];
    for (final fraction in [0.25, 0.5, 0.75]) {
      final idx =
          (points.length * fraction).floor().clamp(0, points.length - 2);
      final bearing =
          const Distance().bearing(points[idx], points[idx + 1]);
      markers.add(Marker(
        point: points[idx],
        width: 20,
        height: 20,
        child: Transform.rotate(
          angle: bearing * pi / 180.0,
          child: Icon(Icons.navigation, size: 14, color: color),
        ),
      ));
    }
    return markers;
  }

  double _fitZoomCached(List<LatLng> points) {
    if (_cachedFitZoom != null && identical(points, _cachedFitZoomPoints)) {
      return _cachedFitZoom!;
    }
    _cachedFitZoomPoints = points;
    _cachedFitZoom = _fitZoom(points);
    return _cachedFitZoom!;
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
