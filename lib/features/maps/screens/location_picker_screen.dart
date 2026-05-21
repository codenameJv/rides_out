import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/tile_cache_service.dart';
import '../../../core/services/nominatim_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../local_db/models/geo_point_model.dart';

class LocationPickerScreen extends StatefulWidget {
  final GeoPointModel? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  LatLng? _selectedPoint;
  String? _placeName;
  List<NominatimPlace> _searchResults = [];
  bool _showResults = false;
  bool _isSearching = false;
  bool _isReversing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedPoint = LatLng(
        widget.initialLocation!.latitude,
        widget.initialLocation!.longitude,
      );
      _reverseGeocode(_selectedPoint!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedPoint = point;
      _placeName = null;
      _showResults = false;
    });
    _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isReversing = true);
    final name =
        await NominatimService.reverse(point.latitude, point.longitude);
    if (mounted) {
      setState(() {
        _placeName = name;
        _isReversing = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }
    _debounce = Timer(const Duration(seconds: 1), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final results = await NominatimService.search(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _showResults = results.isNotEmpty;
        _isSearching = false;
      });
    }
  }

  void _selectSearchResult(NominatimPlace place) {
    final point = LatLng(place.lat, place.lon);
    setState(() {
      _selectedPoint = point;
      _placeName = place.displayName;
      _showResults = false;
      _searchController.clear();
    });
    _mapController.move(point, 14);
  }

  Future<void> _goToMyLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        14,
      );
    } catch (_) {}
  }

  void _confirm() {
    if (_selectedPoint == null) return;
    Navigator.pop(
      context,
      GeoPointModel(
        latitude: _selectedPoint!.latitude,
        longitude: _selectedPoint!.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = widget.initialLocation != null
        ? LatLng(
            widget.initialLocation!.latitude,
            widget.initialLocation!.longitude,
          )
        : LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
    final initialZoom =
        widget.initialLocation != null ? 14.0 : AppConstants.defaultMapZoom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pick Location')),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: AppConstants.osmTileUrl,
                userAgentPackageName: 'com.ridesout.app',
                tileProvider: TileCacheService.tileProvider,
              ),
              CurrentLocationLayer(),
              if (_selectedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
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
          ),

          // Search bar + results
          Positioned(
            top: AppDimensions.paddingSM,
            left: AppDimensions.paddingSM,
            right: AppDimensions.paddingSM,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search for a place...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child:
                                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                      _showResults = false;
                                    });
                                  },
                                )
                              : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSM),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                if (_showResults)
                  Material(
                    elevation: 4,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSM),
                    color: AppColors.surface,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.surfaceLight),
                      itemBuilder: (context, index) {
                        final place = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place,
                              color: AppColors.primary, size: 20),
                          title: Text(
                            place.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () => _selectSearchResult(place),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // My location button
          Positioned(
            right: AppDimensions.paddingSM,
            bottom: _selectedPoint != null ? 160 : AppDimensions.paddingMD,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
              backgroundColor: AppColors.surface,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),

          // Bottom bar
          if (_selectedPoint != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: AppDimensions.paddingMD,
                  right: AppDimensions.paddingMD,
                  top: AppDimensions.paddingMD,
                  bottom: MediaQuery.of(context).padding.bottom +
                      AppDimensions.paddingMD,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${_selectedPoint!.latitude.toStringAsFixed(6)}, ${_selectedPoint!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_isReversing)
                      const Text(
                        'Looking up address...',
                        style: TextStyle(
                            color: AppColors.textHint, fontSize: 12),
                      )
                    else if (_placeName != null)
                      Text(
                        _placeName!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check),
                      label: const Text('Confirm Location'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusSM),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
