import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/offline_map_service.dart';
import '../../../core/services/tile_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';

class RegionPickerScreen extends StatefulWidget {
  const RegionPickerScreen({super.key});

  @override
  State<RegionPickerScreen> createState() => _RegionPickerScreenState();
}

class _RegionPickerScreenState extends State<RegionPickerScreen> {
  final MapController _mapController = MapController();
  final _nameController = TextEditingController(text: 'My Region');

  // Region bounds - default to view area
  double _south = 14.4;
  double _north = 14.8;
  double _west = 120.9;
  double _east = 121.1;

  int _minZoom = 6;
  int _maxZoom = 14;
  bool _downloading = false;
  int _downloadedCount = 0;
  int _totalTileCount = 0;

  int get _tileCount => OfflineMapService.calculateTileCount(
        south: _south,
        west: _west,
        north: _north,
        east: _east,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
      );

  void _updateBoundsFromMap() {
    final bounds = _mapController.camera.visibleBounds;
    setState(() {
      _south = bounds.south;
      _north = bounds.north;
      _west = bounds.west;
      _east = bounds.east;
    });
  }

  Future<void> _download() async {
    final count = _tileCount;
    if (count > 10000) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Large Download'),
          content: Text(
            'This will download $count tiles. '
            'This may take a while and use significant storage.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Download'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _downloading = true;
      _downloadedCount = 0;
      _totalTileCount = count;
    });

    final region = await OfflineMapService.downloadRegion(
      id: const Uuid().v4(),
      name: _nameController.text.trim().isEmpty
          ? 'Region'
          : _nameController.text.trim(),
      south: _south,
      west: _west,
      north: _north,
      east: _east,
      minZoom: _minZoom,
      maxZoom: _maxZoom,
      onProgress: (downloaded, total) {
        if (mounted) {
          setState(() {
            _downloadedCount = downloaded;
            _totalTileCount = total;
          });
        }
      },
    );

    if (mounted) {
      Navigator.pop(context, region);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tileCount = _tileCount;
    final estimatedSize = tileCount * 15; // ~15KB per tile average

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Download Region'),
        actions: [
          if (!_downloading)
            FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download),
              label: const Text('Download'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                        AppConstants.defaultLat, AppConstants.defaultLng),
                    initialZoom: 10,
                    onPositionChanged: (_, _) => _updateBoundsFromMap(),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: AppConstants.osmTileUrl,
                      userAgentPackageName: 'com.ridesout.app',
                      tileProvider: TileCacheService.tileProvider,
                    ),
                    // Bounding box overlay
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: [
                            LatLng(_north, _west),
                            LatLng(_north, _east),
                            LatLng(_south, _east),
                            LatLng(_south, _west),
                          ],
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderColor: AppColors.primary,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  ],
                ),
                // Cross hair
                const Center(
                  child: Icon(Icons.add,
                      size: 32, color: AppColors.primary),
                ),
              ],
            ),
          ),
          // Controls
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Region name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Zoom range
                Row(
                  children: [
                    const Text('Zoom range: '),
                    DropdownButton<int>(
                      value: _minZoom,
                      underline: const SizedBox(),
                      items: List.generate(10, (i) => i + 4)
                          .map((z) => DropdownMenuItem(
                              value: z, child: Text('$z')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _minZoom = v);
                      },
                    ),
                    const Text(' to '),
                    DropdownButton<int>(
                      value: _maxZoom,
                      underline: const SizedBox(),
                      items: List.generate(10, (i) => i + 8)
                          .map((z) => DropdownMenuItem(
                              value: z, child: Text('$z')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _maxZoom = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Tile count and estimated size
                Text(
                  '$tileCount tiles · ~${OfflineMapService.formatSize(estimatedSize * 1024)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: tileCount > 10000
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
                // Download progress
                if (_downloading) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _totalTileCount > 0
                        ? _downloadedCount / _totalTileCount
                        : null,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Downloading $_downloadedCount / $_totalTileCount tiles...',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
