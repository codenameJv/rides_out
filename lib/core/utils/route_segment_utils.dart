import '../../local_db/models/route_point_model.dart';
import 'distance_calculator.dart';

class RouteSegmentUtils {
  RouteSegmentUtils._();

  static const Duration defaultGapThreshold = Duration(minutes: 30);

  /// Split a flat list of route points into segments by detecting timestamp
  /// gaps larger than [threshold] between consecutive points.
  static List<List<RoutePointModel>> splitIntoSegments(
    List<RoutePointModel> points, {
    Duration threshold = defaultGapThreshold,
  }) {
    if (points.isEmpty) return [];

    final segments = <List<RoutePointModel>>[];
    var current = <RoutePointModel>[points.first];

    for (int i = 1; i < points.length; i++) {
      final gap = points[i].timestamp.difference(points[i - 1].timestamp);
      if (gap > threshold) {
        segments.add(current);
        current = <RoutePointModel>[points[i]];
      } else {
        current.add(points[i]);
      }
    }
    segments.add(current);

    return segments;
  }

  /// Compute stats for a single segment.
  static ({double distanceKm, Duration duration}) segmentStats(
    List<RoutePointModel> segment,
  ) {
    if (segment.length < 2) {
      return (distanceKm: 0.0, duration: Duration.zero);
    }

    double dist = 0;
    for (int i = 0; i < segment.length - 1; i++) {
      dist += DistanceCalculator.distanceKm(
        segment[i].latitude,
        segment[i].longitude,
        segment[i + 1].latitude,
        segment[i + 1].longitude,
      );
    }

    final duration =
        segment.last.timestamp.difference(segment.first.timestamp);

    return (distanceKm: dist, duration: duration);
  }

  /// Aggregate stats across all segments.
  static ({double distanceKm, Duration duration, int segmentCount}) totalStats(
    List<List<RoutePointModel>> segments,
  ) {
    double totalDist = 0;
    Duration totalDur = Duration.zero;

    for (final seg in segments) {
      final stats = segmentStats(seg);
      totalDist += stats.distanceKm;
      totalDur += stats.duration;
    }

    return (
      distanceKm: totalDist,
      duration: totalDur,
      segmentCount: segments.length,
    );
  }
}
