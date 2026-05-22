import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import 'hive_service.dart';

class OsrmRoute {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const OsrmRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class OsrmService {
  OsrmService._();

  static const _baseUrl = 'router.project-osrm.org';
  static const _userAgent = 'RidesOut/1.0';

  // In-memory cache keyed by rounded coords (4 decimal places) + exclude flag
  static final Map<String, List<LatLng>> _cache = {};
  static final Map<String, List<OsrmRoute>> _altCache = {};

  static bool get _avoidTollsExpressways =>
      HiveService.settingsBox
          .get('avoid_tolls_expressways', defaultValue: false) as bool;

  static String _cacheKey(LatLng from, LatLng to, {bool withExclude = false}) {
    final fLat = from.latitude.toStringAsFixed(4);
    final fLng = from.longitude.toStringAsFixed(4);
    final tLat = to.latitude.toStringAsFixed(4);
    final tLng = to.longitude.toStringAsFixed(4);
    final suffix = withExclude ? ':noMW' : '';
    return '$fLat,$fLng;$tLat,$tLng$suffix';
  }

  /// Raw HTTP fetch that returns decoded JSON or null on failure.
  static Future<Map<String, dynamic>?> _fetch(Uri uri) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', _userAgent);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = json.decode(body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Build OSRM URI, optionally with exclude=motorway,toll.
  static Uri _buildUri(
    String coords,
    Map<String, String> baseParams, {
    bool withExclude = false,
  }) {
    final params = Map<String, String>.from(baseParams);
    if (withExclude) params['exclude'] = 'motorway,toll';
    return Uri.https(_baseUrl, '/route/v1/driving/$coords', params);
  }

  /// Fetches road geometry between two points from OSRM.
  /// Returns a list of [LatLng] representing the road route.
  /// Falls back to a straight line on any error.
  static Future<List<LatLng>> getRoute(LatLng from, LatLng to) async {
    final wantExclude = _avoidTollsExpressways;
    final key = _cacheKey(from, to, withExclude: wantExclude);
    if (_cache.containsKey(key)) return _cache[key]!;

    final coords =
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    const baseParams = {'overview': 'full', 'geometries': 'geojson'};

    // Try with exclude first if requested, fall back without it
    Map<String, dynamic>? data;
    if (wantExclude) {
      data = await _fetch(
          _buildUri(coords, baseParams, withExclude: true));
    }
    data ??= await _fetch(_buildUri(coords, baseParams));

    if (data == null) return [from, to];

    final routes = data['routes'] as List<dynamic>;
    if (routes.isEmpty) return [from, to];

    final geometry = routes[0]['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;

    final points = coordinates.map((coord) {
      final c = coord as List<dynamic>;
      return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
    }).toList();

    if (points.length < 2) return [from, to];

    _cache[key] = points;
    return points;
  }

  /// Fetches up to 3 route alternatives between two points.
  static Future<List<OsrmRoute>> getRouteAlternatives(
      LatLng from, LatLng to) async {
    final wantExclude = _avoidTollsExpressways;
    final key = _cacheKey(from, to, withExclude: wantExclude);
    if (_altCache.containsKey(key)) return _altCache[key]!;

    final coords =
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    const baseParams = {
      'overview': 'full',
      'geometries': 'geojson',
      'alternatives': '3',
    };

    final fallback = [
      OsrmRoute(points: [from, to], distanceMeters: 0, durationSeconds: 0)
    ];

    // Try with exclude first if requested, fall back without it
    Map<String, dynamic>? data;
    if (wantExclude) {
      data = await _fetch(
          _buildUri(coords, baseParams, withExclude: true));
    }
    data ??= await _fetch(_buildUri(coords, baseParams));

    if (data == null) return fallback;

    final routes = data['routes'] as List<dynamic>;
    if (routes.isEmpty) return fallback;

    final result = <OsrmRoute>[];
    for (final route in routes) {
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final points = coordinates.map((coord) {
        final c = coord as List<dynamic>;
        return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
      }).toList();

      if (points.length < 2) continue;

      result.add(OsrmRoute(
        points: points,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      ));
    }

    if (result.isEmpty) return fallback;

    _cache[key] = result.first.points;
    _altCache[key] = result;
    return result;
  }

  /// Fetches road routes for each consecutive pair of stops.
  static Future<List<List<LatLng>>> getRouteLegs(List<LatLng> stops) async {
    if (stops.length < 2) return [];

    final futures = <Future<List<LatLng>>>[];
    for (int i = 0; i < stops.length - 1; i++) {
      futures.add(getRoute(stops[i], stops[i + 1]));
    }
    return Future.wait(futures);
  }

  /// Fetches alternatives for each consecutive pair of stops.
  /// Returns a list of alternative lists, one per leg.
  static Future<List<List<OsrmRoute>>> getRouteLegAlternatives(
      List<LatLng> stops) async {
    if (stops.length < 2) return [];

    final futures = <Future<List<OsrmRoute>>>[];
    for (int i = 0; i < stops.length - 1; i++) {
      futures.add(getRouteAlternatives(stops[i], stops[i + 1]));
    }
    return Future.wait(futures);
  }

  /// Builds combined full-route alternatives from per-leg alternatives.
  /// Route 1 uses primary (index 0) for every leg.
  /// Additional routes swap one leg at a time to its next alternative.
  /// Returns up to [maxRoutes] combined routes.
  static List<OsrmRoute> buildCombinedAlternatives(
    List<List<OsrmRoute>> legAlternatives, {
    int maxRoutes = 3,
  }) {
    if (legAlternatives.isEmpty) return [];

    // Route 1: all primary legs
    final primaryPoints = <List<LatLng>>[];
    double primaryDist = 0;
    double primaryDur = 0;
    for (final legAlts in legAlternatives) {
      final primary = legAlts.first;
      primaryPoints.add(primary.points);
      primaryDist += primary.distanceMeters;
      primaryDur += primary.durationSeconds;
    }

    final results = <OsrmRoute>[
      OsrmRoute(
        points: flattenLegs(primaryPoints),
        distanceMeters: primaryDist,
        durationSeconds: primaryDur,
      ),
    ];

    // Additional routes: swap one leg at a time to each of its alternatives
    for (int legIdx = 0;
        legIdx < legAlternatives.length && results.length < maxRoutes;
        legIdx++) {
      for (int altIdx = 1;
          altIdx < legAlternatives[legIdx].length &&
              results.length < maxRoutes;
          altIdx++) {
        final altLeg = legAlternatives[legIdx][altIdx];
        final altPoints = <List<LatLng>>[];
        double altDist = 0;
        double altDur = 0;

        for (int i = 0; i < legAlternatives.length; i++) {
          final leg = (i == legIdx) ? altLeg : legAlternatives[i].first;
          altPoints.add(leg.points);
          altDist += leg.distanceMeters;
          altDur += leg.durationSeconds;
        }

        results.add(OsrmRoute(
          points: flattenLegs(altPoints),
          distanceMeters: altDist,
          durationSeconds: altDur,
        ));
      }
    }

    return results;
  }

  /// Merges legs into a single polyline, deduplicating junction points.
  static List<LatLng> flattenLegs(List<List<LatLng>> legs) {
    if (legs.isEmpty) return [];

    final result = <LatLng>[...legs.first];
    for (int i = 1; i < legs.length; i++) {
      final leg = legs[i];
      if (leg.isEmpty) continue;
      // Skip first point of subsequent legs if it matches last point of result
      final startIdx =
          (result.isNotEmpty && leg.first == result.last) ? 1 : 0;
      result.addAll(leg.sublist(startIdx));
    }
    return result;
  }
}
