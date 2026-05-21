import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import '../../../core/constants/app_constants.dart';
import '../../../core/services/tile_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../providers/ride_tracking_provider.dart';

class RideTrackingScreen extends ConsumerStatefulWidget {
  final String tripId;

  const RideTrackingScreen({super.key, required this.tripId});

  @override
  ConsumerState<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends ConsumerState<RideTrackingScreen> {
  final MapController _mapController = MapController();
  Timer? _elapsedTimer;
  bool _hasStarted = false;
  bool _startError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTracking());
  }

  Future<void> _startTracking() async {
    final notifier = ref.read(rideTrackingProvider.notifier);
    final success = await notifier.startTracking(widget.tripId);

    if (!mounted) return;

    if (!success) {
      setState(() => _startError = true);
      return;
    }

    setState(() => _hasStarted = true);

    // Update elapsed time every second
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(rideTrackingProvider.notifier).updateElapsed();
    });
  }

  Future<void> _stopAndSave() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Stop Ride',
      message:
          'Stop recording and save this route to your trip?',
      confirmLabel: 'Stop & Save',
      confirmColor: AppColors.primary,
    );

    if (!confirmed || !mounted) return;

    await ref.read(rideTrackingProvider.notifier).stopAndSave();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ride saved to trip')),
    );
    context.pop();
  }

  void _togglePause() {
    final state = ref.read(rideTrackingProvider);
    final notifier = ref.read(rideTrackingProvider.notifier);
    if (state.isPaused) {
      notifier.resumeTracking();
    } else {
      notifier.pauseTracking();
    }
  }

  void _centerOnUser() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (_) {}
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(rideTrackingProvider);

    if (_startError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ride Tracking')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.paddingLG),
            child: Text(
              'Location permission is required to track your ride. '
              'Please enable it in your device settings.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!_hasStarted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ride Tracking')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final trailPoints = trackingState.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    final center = trailPoints.isNotEmpty
        ? trailPoints.last
        : LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: AppConstants.osmTileUrl,
                userAgentPackageName: 'com.ridesout.app',
                tileProvider: TileCacheService.tileProvider,
              ),
              if (trailPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trailPoints,
                      strokeWidth: AppDimensions.mapLineWidth + 1,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              CurrentLocationLayer(),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(AppConstants.osmAttribution),
                ],
              ),
            ],
          ),

          // Top stats bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: AppDimensions.paddingMD,
            right: AppDimensions.paddingMD,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMD,
                vertical: AppDimensions.paddingSM,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () async {
                      if (trackingState.isTracking) {
                        final confirmed = await ConfirmDialog.show(
                          context,
                          title: 'Discard Ride?',
                          message:
                              'Going back will discard the current ride recording.',
                          confirmLabel: 'Discard',
                        );
                        if (!confirmed || !context.mounted) return;
                        ref.read(rideTrackingProvider.notifier).cancel();
                      }
                      if (context.mounted) context.pop();
                    },
                  ),
                  // Time
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDuration(trackingState.elapsedDuration),
                        style: AppTextStyles.headlineSmall,
                      ),
                      Text('Time', style: AppTextStyles.bodySmall),
                    ],
                  ),
                  // Distance
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DistanceCalculator.formatDistance(
                            trackingState.distanceMiles),
                        style: AppTextStyles.headlineSmall,
                      ),
                      Text('Distance', style: AppTextStyles.bodySmall),
                    ],
                  ),
                  // Points count
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${trackingState.points.length}',
                        style: AppTextStyles.headlineSmall,
                      ),
                      Text('Points', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Paused indicator
          if (trackingState.isPaused)
            Positioned(
              top: MediaQuery.of(context).padding.top + 76,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMD,
                    vertical: AppDimensions.paddingXS,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.9),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSM),
                  ),
                  child: const Text(
                    'PAUSED',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: AppDimensions.paddingMD,
            right: AppDimensions.paddingMD,
            child: Row(
              children: [
                // Center on user
                FloatingActionButton(
                  heroTag: 'center',
                  mini: true,
                  backgroundColor: AppColors.surface,
                  onPressed: _centerOnUser,
                  child: const Icon(Icons.my_location,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(width: AppDimensions.paddingSM),
                // Pause/Resume
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _togglePause,
                    icon: Icon(trackingState.isPaused
                        ? Icons.play_arrow
                        : Icons.pause),
                    label: Text(trackingState.isPaused ? 'Resume' : 'Pause'),
                    style: FilledButton.styleFrom(
                      backgroundColor: trackingState.isPaused
                          ? Colors.green
                          : Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.paddingSM),
                // Stop & Save
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _stopAndSave,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop & Save'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
