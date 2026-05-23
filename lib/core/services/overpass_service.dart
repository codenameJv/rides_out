import 'dart:convert';
import 'dart:io';

class PoiModel {
  final String name;
  final double lat;
  final double lon;
  final String category;
  final Map<String, String> tags;

  const PoiModel({
    required this.name,
    required this.lat,
    required this.lon,
    required this.category,
    this.tags = const {},
  });
}

class OverpassService {
  OverpassService._();

  static const _apiUrl = 'https://overpass-api.de/api/interpreter';
  static const _maxResults = 200;

  static final Map<String, List<PoiModel>> _cache = {};

  static const Map<String, String> categories = {
    'fuel': 'amenity=fuel',
    'food': 'amenity~"restaurant|cafe|fast_food"',
    'lodging': 'tourism~"hotel|motel|hostel"',
    'camping': 'tourism=camp_site',
    'viewpoint': 'tourism=viewpoint',
  };

  static const Map<String, String> categoryIcons = {
    'fuel': '\u26FD',
    'food': '\uD83C\uDF54',
    'lodging': '\uD83C\uDFE8',
    'camping': '\u26FA',
    'viewpoint': '\uD83D\uDC41',
  };

  static Future<List<PoiModel>> searchPois({
    required double south,
    required double west,
    required double north,
    required double east,
    required String category,
  }) async {
    final key =
        '$category:${south.toStringAsFixed(3)},${west.toStringAsFixed(3)},${north.toStringAsFixed(3)},${east.toStringAsFixed(3)}';
    if (_cache.containsKey(key)) return _cache[key]!;

    final filter = categories[category];
    if (filter == null) return [];

    final bbox = '$south,$west,$north,$east';
    final query = '''
[out:json][timeout:10];
(
  node[$filter]($bbox);
  way[$filter]($bbox);
);
out center $_maxResults;
''';

    try {
      final client = HttpClient();
      final uri = Uri.parse(_apiUrl);
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      request.headers.set('User-Agent', 'RidesOut/1.0');
      request.write('data=${Uri.encodeComponent(query)}');
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = json.decode(body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>? ?? [];

      final pois = <PoiModel>[];
      for (final el in elements) {
        final tags =
            (el['tags'] as Map<String, dynamic>?)?.cast<String, String>() ??
                {};
        final name = tags['name'] ?? category;

        double lat, lon;
        if (el['type'] == 'node') {
          lat = (el['lat'] as num).toDouble();
          lon = (el['lon'] as num).toDouble();
        } else if (el['center'] != null) {
          lat = (el['center']['lat'] as num).toDouble();
          lon = (el['center']['lon'] as num).toDouble();
        } else {
          continue;
        }

        pois.add(PoiModel(
          name: name,
          lat: lat,
          lon: lon,
          category: category,
          tags: tags,
        ));
      }

      _cache[key] = pois;
      return pois;
    } catch (_) {
      return [];
    }
  }
}
