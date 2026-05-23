import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

class OfflineRegion {
  final String id;
  final String name;
  final double south;
  final double west;
  final double north;
  final double east;
  final int minZoom;
  final int maxZoom;
  final int tileCount;
  final int sizeBytes;
  final DateTime createdAt;

  const OfflineRegion({
    required this.id,
    required this.name,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.minZoom,
    required this.maxZoom,
    required this.tileCount,
    required this.sizeBytes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'south': south,
        'west': west,
        'north': north,
        'east': east,
        'minZoom': minZoom,
        'maxZoom': maxZoom,
        'tileCount': tileCount,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OfflineRegion.fromJson(Map<String, dynamic> json) => OfflineRegion(
        id: json['id'] as String,
        name: json['name'] as String,
        south: (json['south'] as num).toDouble(),
        west: (json['west'] as num).toDouble(),
        north: (json['north'] as num).toDouble(),
        east: (json['east'] as num).toDouble(),
        minZoom: json['minZoom'] as int,
        maxZoom: json['maxZoom'] as int,
        tileCount: json['tileCount'] as int,
        sizeBytes: json['sizeBytes'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class OfflineMapService {
  OfflineMapService._();

  static const _tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _userAgent = 'RidesOut/1.0';

  static Future<Directory> get _tilesDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/offline_tiles');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // Tile math helpers
  static int _lon2tile(double lon, int zoom) {
    return ((lon + 180) / 360 * pow(2, zoom)).floor();
  }

  static int _lat2tile(double lat, int zoom) {
    return ((1 -
                log(tan(lat * pi / 180) + 1 / cos(lat * pi / 180)) /
                    pi) /
            2 *
            pow(2, zoom))
        .floor();
  }

  /// Calculate the number of tiles in a bounding box at given zoom range.
  static int calculateTileCount({
    required double south,
    required double west,
    required double north,
    required double east,
    required int minZoom,
    required int maxZoom,
  }) {
    int count = 0;
    for (int z = minZoom; z <= maxZoom; z++) {
      final x1 = _lon2tile(west, z);
      final x2 = _lon2tile(east, z);
      final y1 = _lat2tile(north, z);
      final y2 = _lat2tile(south, z);
      count += (x2 - x1 + 1) * (y2 - y1 + 1);
    }
    return count;
  }

  /// Download tiles for a region with progress callback.
  /// Respects OSM usage policy: max 2 concurrent downloads.
  static Future<OfflineRegion> downloadRegion({
    required String id,
    required String name,
    required double south,
    required double west,
    required double north,
    required double east,
    int minZoom = 6,
    int maxZoom = 14,
    void Function(int downloaded, int total)? onProgress,
  }) async {
    final dir = await _tilesDir;
    final tileCount = calculateTileCount(
      south: south,
      west: west,
      north: north,
      east: east,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );

    int downloaded = 0;
    int totalSize = 0;

    // Build tile list
    final tiles = <({int z, int x, int y})>[];
    for (int z = minZoom; z <= maxZoom; z++) {
      final x1 = _lon2tile(west, z);
      final x2 = _lon2tile(east, z);
      final y1 = _lat2tile(north, z);
      final y2 = _lat2tile(south, z);
      for (int x = x1; x <= x2; x++) {
        for (int y = y1; y <= y2; y++) {
          tiles.add((z: z, x: x, y: y));
        }
      }
    }

    // Download with max 2 concurrent (OSM policy)
    final client = HttpClient();
    final semaphore = _Semaphore(2);

    await Future.wait(tiles.map((tile) async {
      await semaphore.acquire();
      try {
        final url = _tileUrlTemplate
            .replaceAll('{z}', '${tile.z}')
            .replaceAll('{x}', '${tile.x}')
            .replaceAll('{y}', '${tile.y}');

        final tileDir =
            Directory('${dir.path}/${tile.z}/${tile.x}');
        if (!await tileDir.exists()) {
          await tileDir.create(recursive: true);
        }
        final file = File('${tileDir.path}/${tile.y}.png');

        if (!await file.exists()) {
          final request = await client.getUrl(Uri.parse(url));
          request.headers.set('User-Agent', _userAgent);
          final response = await request.close();
          final bytes = await response.fold<List<int>>(
              [], (prev, chunk) => prev..addAll(chunk));
          await file.writeAsBytes(bytes);
          totalSize += bytes.length;
        } else {
          totalSize += await file.length();
        }

        downloaded++;
        onProgress?.call(downloaded, tileCount);
      } catch (_) {
        downloaded++;
        onProgress?.call(downloaded, tileCount);
      } finally {
        semaphore.release();
      }
    }));

    client.close();

    return OfflineRegion(
      id: id,
      name: name,
      south: south,
      west: west,
      north: north,
      east: east,
      minZoom: minZoom,
      maxZoom: maxZoom,
      tileCount: tileCount,
      sizeBytes: totalSize,
      createdAt: DateTime.now(),
    );
  }

  /// Get a local tile file if it exists, null otherwise.
  static Future<File?> getTile(int z, int x, int y) async {
    final dir = await _tilesDir;
    final file = File('${dir.path}/$z/$x/$y.png');
    if (await file.exists()) return file;
    return null;
  }

  /// Delete a downloaded region's tiles.
  static Future<void> deleteRegion(OfflineRegion region) async {
    final dir = await _tilesDir;
    for (int z = region.minZoom; z <= region.maxZoom; z++) {
      final x1 = _lon2tile(region.west, z);
      final x2 = _lon2tile(region.east, z);
      final y1 = _lat2tile(region.north, z);
      final y2 = _lat2tile(region.south, z);

      for (int x = x1; x <= x2; x++) {
        for (int y = y1; y <= y2; y++) {
          final file = File('${dir.path}/$z/$x/$y.png');
          if (await file.exists()) await file.delete();
        }
      }
    }
  }

  /// Get total offline storage size.
  static Future<int> getTotalStorageSize() async {
    final dir = await _tilesDir;
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _Semaphore {
  final int _maxCount;
  int _currentCount = 0;

  _Semaphore(this._maxCount);

  Future<void> acquire() async {
    while (_currentCount >= _maxCount) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _currentCount++;
  }

  void release() {
    _currentCount--;
  }
}
