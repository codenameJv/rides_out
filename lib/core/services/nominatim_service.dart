import 'dart:convert';
import 'dart:io';

class NominatimPlace {
  final String displayName;
  final double lat;
  final double lon;

  const NominatimPlace({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory NominatimPlace.fromJson(Map<String, dynamic> json) {
    return NominatimPlace(
      displayName: json['display_name'] as String,
      lat: double.parse(json['lat'] as String),
      lon: double.parse(json['lon'] as String),
    );
  }
}

class NominatimService {
  NominatimService._();

  static const _baseUrl = 'nominatim.openstreetmap.org';
  static const _userAgent = 'RidesOut/1.0';

  static Future<List<NominatimPlace>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.https(_baseUrl, '/search', {
      'q': query,
      'format': 'json',
      'limit': '5',
    });

    try {
      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', _userAgent);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final List<dynamic> data = json.decode(body);
      return data.map((e) => NominatimPlace.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> reverse(double lat, double lon) async {
    final uri = Uri.https(_baseUrl, '/reverse', {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'format': 'json',
    });

    try {
      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', _userAgent);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = json.decode(body) as Map<String, dynamic>;
      return data['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
