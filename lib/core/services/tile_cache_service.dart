import 'dart:io';

import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:path_provider/path_provider.dart';

class TileCacheService {
  static late FileCacheStore _store;

  static Future<void> init() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/map_tiles');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    _store = FileCacheStore(cacheDir.path);
  }

  static CachedTileProvider get tileProvider => CachedTileProvider(
        store: _store,
        maxStale: const Duration(days: 30),
      );

  static Future<void> clearCache() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/map_tiles');
    if (cacheDir.existsSync()) {
      await cacheDir.delete(recursive: true);
      await cacheDir.create(recursive: true);
    }
    _store = FileCacheStore(cacheDir.path);
  }

  static Future<int> getCacheSize() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/map_tiles');
    if (!cacheDir.existsSync()) return 0;
    int total = 0;
    await for (final entity in cacheDir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  static String formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
