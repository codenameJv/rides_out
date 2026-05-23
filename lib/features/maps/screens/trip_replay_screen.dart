import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import '../../../core/constants/app_constants.dart';
import '../../../core/services/osrm_service.dart';
import '../../../core/services/tile_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../../core/utils/route_segment_utils.dart';
import '../../../local_db/models/itinerary_stop_model.dart';
import '../../../local_db/models/route_point_model.dart';
import '../../itinerary/providers/itinerary_provider.dart';
import '../../trips/providers/trips_provider.dart';
import '../widgets/compass_button.dart';
import '../widgets/replay_controls.dart';
import '../widgets/speed_legend.dart';
import '../widgets/stop_marker.dart';
import '../widgets/zoom_buttons.dart';

class _RouteSegment {
  final List<LatLng> points;
  final List<double> cumulativeDistances;
  final double startProgress;
  final double endProgress;
  final int stopIndex; // index of the destination stop

  const _RouteSegment({
    required this.points,
    required this.cumulativeDistances,
    required this.startProgress,
    required this.endProgress,
    required this.stopIndex,
  });
}

class TripReplayScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripReplayScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripReplayScreen> createState() => _TripReplayScreenState();
}

class _TripReplayScreenState extends ConsumerState<TripReplayScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _animationController;
  late AnimationController _pulseController;

  List<LatLng> _routePoints = [];
  List<_RouteSegment> _segments = [];
  List<ItineraryStopModel> _stopsWithLocation = [];
  double _speed = 0.5;
  int _currentStopIndex = 0;
  bool _showStopCard = true;
  bool _isLoadingRoute = true;
  Timer? _stopCardTimer;
  double _mapRotation = 0.0;
  StreamSubscription? _mapEventSub;
  bool _showSpeedViz = false;
  List<double> _speeds = [];
  bool _hasTimestamps = false;

  // Per-segment distances in km (segment i = stop i → stop i+1)
  List<double> _segmentDistances = [];

  // Cached per-frame values (updated in _onAnimationTick, read in build)
  List<LatLng> _cachedDrawnPoints = [];
  LatLng? _cachedRiderPos;
  // Cached speed polylines (computed once at setup, not per frame)
  List<Polyline> _cachedSpeedPolylines = [];

  // Smooth zoom state
  double _currentZoom = 15.0;
  static const double _cruiseZoom = 15.0;
  static const double _stopZoom = 15.5;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _animationController.addListener(_onAnimationTick);
    _animationController.addStatusListener(_onAnimationStatus);

    _mapEventSub = _mapController.mapEventStream.listen((event) {
      if (event is MapEventRotate || event is MapEventRotateEnd) {
        setState(() => _mapRotation = _mapController.camera.rotation * 3.14159265 / 180.0);
      }
    });

    // Pulse animation for rider marker glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Defer setup to allow ref to be available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRoute();
    });
  }

  // All stops with location (including shape points) for routing
  List<ItineraryStopModel> _allStopsWithLocation = [];

  Future<void> _setupRoute() async {
    final stops = ref.read(itineraryProvider(widget.tripId));
    _allStopsWithLocation = stops.where((s) => s.location != null).toList();
    // Display-only stops exclude shape points
    _stopsWithLocation = _allStopsWithLocation.where((s) => !s.type.isShapeOnly).toList();

    // Check if the trip has a recorded GPS route
    final trip = ref.read(tripByIdProvider(widget.tripId));
    final List<RoutePointModel> recordedRoute = trip?.recordedRoute ?? [];

    List<List<LatLng>> legs;

    if (recordedRoute.length >= 2) {
      // Split recorded route into segments by timestamp gaps
      final segments =
          RouteSegmentUtils.splitIntoSegments(recordedRoute);
      legs = segments
          .map((seg) =>
              seg.map((p) => LatLng(p.latitude, p.longitude)).toList())
          .toList();
      _routePoints = legs.expand((l) => l).toList();
      _hasTimestamps = true;
      _speeds = RouteSegmentUtils.calculateSpeeds(recordedRoute);
    } else {
      if (_allStopsWithLocation.length < 2) {
        if (mounted) setState(() => _isLoadingRoute = false);
        return;
      }

      // Route through ALL stops (including shape points) for accurate geometry
      final allStopPoints = _allStopsWithLocation
          .map((s) => LatLng(s.location!.latitude, s.location!.longitude))
          .toList();

      // Fetch road routes
      final subLegs = await OsrmService.getRouteLegs(allStopPoints);
      if (!mounted) return;

      _routePoints = OsrmService.flattenLegs(subLegs);

      // Merge sub-legs between real stops into visual legs
      legs = [];
      List<LatLng> currentMerged = [];
      for (int i = 0; i < subLegs.length; i++) {
        if (currentMerged.isEmpty) {
          currentMerged = List.from(subLegs[i]);
        } else {
          // Deduplicate junction point
          final startIdx = (subLegs[i].isNotEmpty && subLegs[i].first == currentMerged.last) ? 1 : 0;
          currentMerged.addAll(subLegs[i].sublist(startIdx));
        }
        // If the destination of this sub-leg is a real stop, close the visual leg
        final destIdx = i + 1;
        if (destIdx < _allStopsWithLocation.length && !_allStopsWithLocation[destIdx].type.isShapeOnly) {
          legs.add(currentMerged);
          currentMerged = [];
        }
      }
      // Flush any remaining points
      if (currentMerged.isNotEmpty) {
        legs.add(currentMerged);
      }
    }

    // Build segments with per-point cumulative distances
    final segDistances = <double>[];
    double totalDistance = 0;
    for (final leg in legs) {
      double legDist = 0;
      for (int i = 0; i < leg.length - 1; i++) {
        legDist += DistanceCalculator.distanceKm(
          leg[i].latitude,
          leg[i].longitude,
          leg[i + 1].latitude,
          leg[i + 1].longitude,
        );
      }
      segDistances.add(legDist);
      totalDistance += legDist;
    }

    double cumulative = 0;
    _segments = [];
    for (int i = 0; i < legs.length; i++) {
      final fraction = totalDistance > 0.01
          ? segDistances[i] / totalDistance
          : 1.0 / legs.length;

      // Compute cumulative distances within this leg
      final legPoints = legs[i];
      final cumDists = <double>[0.0];
      for (int j = 0; j < legPoints.length - 1; j++) {
        final d = DistanceCalculator.distanceKm(
          legPoints[j].latitude,
          legPoints[j].longitude,
          legPoints[j + 1].latitude,
          legPoints[j + 1].longitude,
        );
        cumDists.add(cumDists.last + d);
      }

      _segments.add(_RouteSegment(
        points: legPoints,
        cumulativeDistances: cumDists,
        startProgress: cumulative,
        endProgress: cumulative + fraction,
        stopIndex: i + 1,
      ));
      cumulative += fraction;
    }

    // Store each segment's distance in km
    _segmentDistances =
        _segments.map((s) => s.cumulativeDistances.last).toList();

    _animationController.duration = _calcDuration();

    // Pre-compute speed polylines (full route, doesn't change during animation)
    if (_speeds.isNotEmpty && _routePoints.length >= 2) {
      _cachedSpeedPolylines = _buildSpeedPolylines(_routePoints, _speeds);
    }

    setState(() {
      _isLoadingRoute = false;
      _currentStopIndex = 0;
      _showStopCard = true;
    });
  }

  Duration _calcDuration() {
    double totalDist = 0;
    for (final seg in _segments) {
      totalDist += seg.cumulativeDistances.last;
    }
    // ~10s per km, clamped 30-300s for a comfortable pace
    final totalSeconds = (totalDist * 10.0).clamp(30.0, 300.0);
    return Duration(milliseconds: (totalSeconds * 1000 / _speed).round());
  }

  /// Interpolate position along a segment's road points given local progress 0.0–1.0.
  LatLng _interpolateAlongSegment(_RouteSegment seg, double segT) {
    if (seg.points.length < 2) return seg.points.first;

    final totalDist = seg.cumulativeDistances.last;
    if (totalDist <= 0) return seg.points.first;

    final targetDist = segT * totalDist;

    // Find the sub-segment containing targetDist
    for (int i = 0; i < seg.cumulativeDistances.length - 1; i++) {
      if (targetDist <= seg.cumulativeDistances[i + 1]) {
        final segStart = seg.cumulativeDistances[i];
        final segEnd = seg.cumulativeDistances[i + 1];
        final segRange = segEnd - segStart;
        final localT =
            segRange > 0 ? (targetDist - segStart) / segRange : 0.0;

        final lat = seg.points[i].latitude +
            (seg.points[i + 1].latitude - seg.points[i].latitude) * localT;
        final lng = seg.points[i].longitude +
            (seg.points[i + 1].longitude - seg.points[i].longitude) * localT;
        return LatLng(lat, lng);
      }
    }
    return seg.points.last;
  }

  /// Returns road points up to the current interpolated position within the segment.
  List<LatLng> _pointsUpToProgress(_RouteSegment seg, double segT) {
    if (seg.points.length < 2) return [seg.points.first];

    final totalDist = seg.cumulativeDistances.last;
    if (totalDist <= 0) return [seg.points.first];

    final targetDist = segT * totalDist;
    final result = <LatLng>[];

    for (int i = 0; i < seg.cumulativeDistances.length - 1; i++) {
      result.add(seg.points[i]);
      if (targetDist <= seg.cumulativeDistances[i + 1]) {
        // Add interpolated point
        final segStart = seg.cumulativeDistances[i];
        final segEnd = seg.cumulativeDistances[i + 1];
        final segRange = segEnd - segStart;
        final localT =
            segRange > 0 ? (targetDist - segStart) / segRange : 0.0;

        final lat = seg.points[i].latitude +
            (seg.points[i + 1].latitude - seg.points[i].latitude) * localT;
        final lng = seg.points[i].longitude +
            (seg.points[i + 1].longitude - seg.points[i].longitude) * localT;
        result.add(LatLng(lat, lng));
        break;
      }
    }
    return result;
  }

  void _onAnimationTick() {
    // Linear value — constant speed throughout
    final t = _animationController.value;

    if (_segments.isEmpty) return;

    // Find current segment
    _RouteSegment? currentSegment;
    for (final seg in _segments) {
      if (t >= seg.startProgress && t <= seg.endProgress) {
        currentSegment = seg;
        break;
      }
    }
    currentSegment ??= _segments.last;

    // Calculate segment-local progress
    final segRange = currentSegment.endProgress - currentSegment.startProgress;
    final segT = segRange > 0
        ? ((t - currentSegment.startProgress) / segRange).clamp(0.0, 1.0)
        : 1.0;

    // Interpolate position along road points
    final pos = _interpolateAlongSegment(currentSegment, segT);

    // Cache drawn points + rider position (avoid recomputing in build)
    _cachedDrawnPoints = _drawnRoutePoints();
    _cachedRiderPos = _cachedDrawnPoints.isNotEmpty
        ? _cachedDrawnPoints.last
        : _routePoints.isNotEmpty
            ? _routePoints.first
            : pos;

    // Smooth zoom — gently ease toward stop zoom when arriving
    double targetZoom = _cruiseZoom;
    if (segT > 0.85) {
      final approach = (segT - 0.85) / 0.15; // 0→1 over last 15%
      targetZoom = _cruiseZoom + (_stopZoom - _cruiseZoom) * approach;
    }
    // Lerp toward target to prevent sudden jumps
    _currentZoom += (targetZoom - _currentZoom) * 0.1;

    _mapController.move(pos, _currentZoom);

    // Update stop index if changed
    final newStopIndex = segT > 0.95
        ? currentSegment.stopIndex
        : currentSegment.stopIndex - 1;
    if (newStopIndex != _currentStopIndex) {
      setState(() {
        _currentStopIndex = newStopIndex;
        _showStopCard = true;
      });
      _stopCardTimer?.cancel();
      _stopCardTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _animationController.isAnimating) {
          setState(() => _showStopCard = false);
        }
      });
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _currentStopIndex = _stopsWithLocation.length - 1;
        _showStopCard = true;
      });
    }
    if (status == AnimationStatus.dismissed ||
        status == AnimationStatus.completed) {
      setState(() {});
    }
  }

  void _togglePlayPause() {
    if (_segments.isEmpty) return;

    if (_animationController.isAnimating) {
      _animationController.stop();
      setState(() => _showStopCard = true);
    } else {
      if (_animationController.isCompleted) {
        _animationController.reset();
        _currentZoom = _cruiseZoom;
        setState(() {
          _currentStopIndex = 0;
          _showStopCard = true;
        });
      }
      _animationController.forward();
    }
    setState(() {});
  }

  void _restart() {
    _animationController.reset();
    _currentZoom = _cruiseZoom;
    setState(() {
      _currentStopIndex = 0;
      _showStopCard = true;
    });
    _animationController.forward();
  }

  void _cycleSpeed() {
    setState(() {
      if (_speed == 0.5) {
        _speed = 1.0;
      } else if (_speed == 1.0) {
        _speed = 2.0;
      } else {
        _speed = 0.5;
      }
    });

    final currentValue = _animationController.value;
    final wasPlaying = _animationController.isAnimating;
    _animationController.stop();

    _animationController.duration = _calcDuration();

    if (wasPlaying) {
      _animationController.forward(from: currentValue);
    } else {
      _animationController.value = currentValue;
    }
  }

  List<LatLng> _drawnRoutePoints() {
    if (_segments.isEmpty) return [];

    final t = _animationController.value;
    final points = <LatLng>[];

    for (final seg in _segments) {
      if (t >= seg.endProgress) {
        // Completed segment: add all road points (deduplicate junction)
        if (points.isEmpty) {
          points.addAll(seg.points);
        } else {
          final startIdx =
              (seg.points.isNotEmpty && seg.points.first == points.last)
                  ? 1
                  : 0;
          points.addAll(seg.points.sublist(startIdx));
        }
      } else if (t >= seg.startProgress) {
        // Partial segment: add road points up to interpolated position
        final segRange = seg.endProgress - seg.startProgress;
        final segT = segRange > 0
            ? ((t - seg.startProgress) / segRange).clamp(0.0, 1.0)
            : 1.0;
        final partial = _pointsUpToProgress(seg, segT);
        if (points.isEmpty) {
          points.addAll(partial);
        } else {
          final startIdx =
              (partial.isNotEmpty && partial.first == points.last) ? 1 : 0;
          points.addAll(partial.sublist(startIdx));
        }
        break;
      } else {
        break;
      }
    }

    return points;
  }

  List<Polyline> _buildSpeedPolylines(
      List<LatLng> points, List<double> speeds) {
    if (points.length < 2) return [];
    final polylines = <Polyline>[];
    for (int i = 0; i < points.length - 1; i++) {
      final speed = i < speeds.length ? speeds[i] : 0.0;
      polylines.add(Polyline(
        points: [points[i], points[i + 1]],
        strokeWidth: 4,
        color: RouteSegmentUtils.speedColor(speed),
      ));
    }
    return polylines;
  }

  @override
  void dispose() {
    _stopCardTimer?.cancel();
    _mapEventSub?.cancel();
    _animationController.removeListener(_onAnimationTick);
    _animationController.removeStatusListener(_onAnimationStatus);
    _pulseController.dispose();
    _animationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stops = ref.watch(itineraryProvider(widget.tripId));
    final trip = ref.watch(tripByIdProvider(widget.tripId));
    // Exclude shape points from display
    final stopsWithLocation = stops.where((s) => s.location != null && !s.type.isShapeOnly).toList();
    final hasRecorded = trip != null && trip.hasRecordedRoute;

    if (stopsWithLocation.length < 2 && !hasRecorded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Trip Replay')),
        body: const Center(
          child: Text('Need at least 2 stops with locations to replay.'),
        ),
      );
    }

    if (_isLoadingRoute) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Trip Replay'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading route...'),
            ],
          ),
        ),
      );
    }

    final center = _routePoints.isNotEmpty
        ? _routePoints.first
        : LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

    // Determine from/to stop names for controls
    String? fromStop;
    String? toStop;
    if (_stopsWithLocation.isNotEmpty) {
      fromStop = _currentStopIndex < _stopsWithLocation.length
          ? _stopsWithLocation[_currentStopIndex].name
          : null;
      final nextIdx = _currentStopIndex + 1;
      toStop = nextIdx < _stopsWithLocation.length
          ? _stopsWithLocation[nextIdx].name
          : null;
    }

    // Current stop for info card
    final currentStop = _currentStopIndex < _stopsWithLocation.length
        ? _stopsWithLocation[_currentStopIndex]
        : null;

    // Distance info for the current stop
    // Leg distance = distance of the segment leading TO this stop (segment index = stopIndex - 1)
    String? legDistLabel;
    String? cumulativeDistLabel;
    if (_segmentDistances.isNotEmpty && _currentStopIndex > 0) {
      final legIdx = _currentStopIndex - 1;
      if (legIdx < _segmentDistances.length) {
        final legKm = _segmentDistances[legIdx];
        legDistLabel = DistanceCalculator.formatDistance(legKm);
      }
      // Cumulative = sum of all segments up to this stop
      double cumKm = 0;
      for (int i = 0; i < _currentStopIndex && i < _segmentDistances.length; i++) {
        cumKm += _segmentDistances[i];
      }
      cumulativeDistLabel = DistanceCalculator.formatDistance(cumKm);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(AppDimensions.paddingSM),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Map
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, _) {
              // Use cached values from _onAnimationTick (no recomputation)
              final drawnPoints = _cachedDrawnPoints;
              final riderPos = _cachedRiderPos ??
                  (_routePoints.isNotEmpty
                      ? _routePoints.first
                      : LatLng(AppConstants.defaultLat, AppConstants.defaultLng));

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _cruiseZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom |
                        InteractiveFlag.drag |
                        InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConstants.osmTileUrl,
                    userAgentPackageName: 'com.ridesout.app',
                    tileProvider: TileCacheService.tileProvider,
                  ),
                  // Full route preview (speed-colored or faded)
                  if (_routePoints.length >= 2 && _showSpeedViz && _cachedSpeedPolylines.isNotEmpty)
                    PolylineLayer(
                      polylines: _cachedSpeedPolylines,
                    )
                  else if (_routePoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 2,
                          color: AppColors.textHint.withValues(alpha: 0.25),
                        ),
                      ],
                    ),
                  // Drawn route glow
                  if (drawnPoints.length >= 2 && !_showSpeedViz)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: drawnPoints,
                          strokeWidth: 8,
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ],
                    ),
                  // Drawn route solid
                  if (drawnPoints.length >= 2 && !_showSpeedViz)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: drawnPoints,
                          strokeWidth: 4,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  // Stop markers
                  MarkerLayer(
                    markers: stopsWithLocation.map((stop) {
                      return Marker(
                        point: LatLng(
                          stop.location!.latitude,
                          stop.location!.longitude,
                        ),
                        width: AppDimensions.mapMarkerSize,
                        height: AppDimensions.mapMarkerSize + 8,
                        child: StopMarkerWidget(stop: stop),
                      );
                    }).toList(),
                  ),
                  // Rider marker with pulsing glow
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: riderPos,
                        width: 40,
                        height: 40,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final pulse = _pulseController.value;
                            final glowSize = 28.0 + pulse * 10.0;
                            final glowAlpha = 0.12 + pulse * 0.08;
                            return Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Pulsing outer glow
                                  Container(
                                    width: glowSize,
                                    height: glowSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary
                                          .withValues(alpha: glowAlpha),
                                    ),
                                  ),
                                  // Core rider dot
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(AppConstants.osmAttribution),
                    ],
                  ),
                ],
              );
            },
          ),

          // Stop info card at top
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: AppDimensions.paddingMD,
            right: AppDimensions.paddingMD,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showStopCard && currentStop != null
                  ? Container(
                      key: ValueKey('stop_${currentStop.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingMD,
                        vertical: AppDimensions.paddingSM,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.92),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMD),
                        border: Border.all(
                          color: AppColors.stopTypeColor(
                              currentStop.type.name),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            currentStop.type.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: AppDimensions.paddingSM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentStop.name,
                                  style: AppTextStyles.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Stop ${_currentStopIndex + 1} of ${_stopsWithLocation.length} \u00B7 ${currentStop.type.label}',
                                  style: AppTextStyles.bodySmall,
                                ),
                                if (legDistLabel != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      cumulativeDistLabel != null && cumulativeDistLabel != legDistLabel
                                          ? '$legDistLabel leg \u00B7 $cumulativeDistLabel total'
                                          : legDistLabel,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // Speed viz toggle + Compass
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
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
                    _currentZoom = (_currentZoom + 1).clamp(3.0, 18.0);
                    _mapController.move(
                        _mapController.camera.center, _currentZoom);
                  },
                  onZoomOut: () {
                    _currentZoom = (_currentZoom - 1).clamp(3.0, 18.0);
                    _mapController.move(
                        _mapController.camera.center, _currentZoom);
                  },
                ),
                if (_hasTimestamps) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _showSpeedViz = !_showSpeedViz),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _showSpeedViz
                            ? AppColors.primary
                            : AppColors.surface.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.textHint.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.speed,
                        size: 20,
                        color: _showSpeedViz
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Speed legend
          if (_showSpeedViz)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: AppDimensions.paddingMD,
              child: const SpeedLegend(),
            ),

          // Replay controls at bottom
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: ReplayControls(
              isPlaying: _animationController.isAnimating,
              progress: _animationController.value,
              speed: _speed,
              fromStop: fromStop,
              toStop: toStop,
              onPlayPause: _togglePlayPause,
              onRestart: _restart,
              onSpeedToggle: _cycleSpeed,
            ),
          ),
        ],
      ),
    );
  }
}
