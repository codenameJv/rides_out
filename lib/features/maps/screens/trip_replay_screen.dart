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
import '../../../local_db/models/itinerary_stop_model.dart';
import '../../../local_db/models/route_point_model.dart';
import '../../itinerary/providers/itinerary_provider.dart';
import '../../trips/providers/trips_provider.dart';
import '../widgets/replay_controls.dart';
import '../widgets/stop_marker.dart';

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

  List<LatLng> _routePoints = [];
  List<_RouteSegment> _segments = [];
  List<ItineraryStopModel> _stopsWithLocation = [];
  double _speed = 1.0;
  int _currentStopIndex = 0;
  bool _showStopCard = true;
  bool _isLoadingRoute = true;
  Timer? _stopCardTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _animationController.addListener(_onAnimationTick);
    _animationController.addStatusListener(_onAnimationStatus);

    // Defer setup to allow ref to be available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRoute();
    });
  }

  Future<void> _setupRoute() async {
    final stops = ref.read(itineraryProvider(widget.tripId));
    _stopsWithLocation = stops.where((s) => s.location != null).toList();

    // Check if the trip has a recorded GPS route
    final trip = ref.read(tripByIdProvider(widget.tripId));
    final List<RoutePointModel> recordedRoute = trip?.recordedRoute ?? [];

    List<List<LatLng>> legs;

    if (recordedRoute.length >= 2) {
      // Use recorded route as a single leg
      final recordedLatLngs = recordedRoute
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      _routePoints = recordedLatLngs;
      legs = [recordedLatLngs];
    } else {
      if (_stopsWithLocation.length < 2) {
        if (mounted) setState(() => _isLoadingRoute = false);
        return;
      }

      final stopPoints = _stopsWithLocation
          .map((s) => LatLng(s.location!.latitude, s.location!.longitude))
          .toList();

      // Fetch road routes from OSRM
      legs = await OsrmService.getRouteLegs(stopPoints);
      if (!mounted) return;

      _routePoints = OsrmService.flattenLegs(legs);
    }

    // Build segments with per-point cumulative distances
    final segDistances = <double>[];
    double totalDistance = 0;
    for (final leg in legs) {
      double legDist = 0;
      for (int i = 0; i < leg.length - 1; i++) {
        legDist += DistanceCalculator.distanceMiles(
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
        final d = DistanceCalculator.distanceMiles(
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

    // Calculate duration: ~3s per segment base, scaled by distance
    final baseDuration = legs.length * 3.0;
    final totalSeconds = baseDuration.clamp(10.0, 60.0);
    _animationController.duration =
        Duration(milliseconds: (totalSeconds * 1000 / _speed).round());

    setState(() {
      _isLoadingRoute = false;
      _currentStopIndex = 0;
      _showStopCard = true;
    });
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

    // Calculate zoom for current segment
    final zoom = _segmentZoom(currentSegment, segT);

    _mapController.move(pos, zoom);

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
      _stopCardTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _animationController.isAnimating) {
          setState(() => _showStopCard = false);
        }
      });
    }
  }

  double _segmentZoom(_RouteSegment seg, double segT) {
    final latDiff =
        (seg.points.last.latitude - seg.points.first.latitude).abs();
    final lngDiff =
        (seg.points.last.longitude - seg.points.first.longitude).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double baseZoom;
    if (maxDiff < 0.005) {
      baseZoom = 14;
    } else if (maxDiff < 0.02) {
      baseZoom = 13;
    } else if (maxDiff < 0.1) {
      baseZoom = 12;
    } else if (maxDiff < 0.5) {
      baseZoom = 10;
    } else {
      baseZoom = 8;
    }

    // Zoom in slightly when arriving at a stop
    if (segT > 0.9) {
      baseZoom += (segT - 0.9) / 0.1 * 0.5; // up to +0.5 zoom
    }

    return baseZoom.clamp(8.0, 14.5);
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
    setState(() {
      _currentStopIndex = 0;
      _showStopCard = true;
    });
    _animationController.forward();
  }

  void _cycleSpeed() {
    setState(() {
      if (_speed == 1.0) {
        _speed = 2.0;
      } else if (_speed == 2.0) {
        _speed = 4.0;
      } else {
        _speed = 1.0;
      }
    });

    // Recalculate duration preserving current progress
    final currentValue = _animationController.value;
    final wasPlaying = _animationController.isAnimating;
    _animationController.stop();

    final baseDuration = _segments.length * 3.0;
    final totalSeconds = baseDuration.clamp(10.0, 60.0);
    _animationController.duration =
        Duration(milliseconds: (totalSeconds * 1000 / _speed).round());

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

  LatLng _currentPosition() {
    if (_segments.isEmpty) {
      return _routePoints.isNotEmpty
          ? _routePoints.first
          : LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
    }
    final drawn = _drawnRoutePoints();
    return drawn.isNotEmpty ? drawn.last : _routePoints.first;
  }

  @override
  void dispose() {
    _stopCardTimer?.cancel();
    _animationController.removeListener(_onAnimationTick);
    _animationController.removeStatusListener(_onAnimationStatus);
    _animationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stops = ref.watch(itineraryProvider(widget.tripId));
    final trip = ref.watch(tripByIdProvider(widget.tripId));
    final stopsWithLocation = stops.where((s) => s.location != null).toList();
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
              final drawnPoints = _drawnRoutePoints();
              final riderPos = _currentPosition();

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 12,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConstants.osmTileUrl,
                    userAgentPackageName: 'com.ridesout.app',
                    tileProvider: TileCacheService.tileProvider,
                  ),
                  // Faded full route preview
                  if (_routePoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: AppDimensions.mapLineWidth,
                          color: AppColors.textHint.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  // Bright drawn route
                  if (drawnPoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: drawnPoints,
                          strokeWidth: AppDimensions.mapLineWidth + 1,
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
                  // Rider marker
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: riderPos,
                        width: 20,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
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
