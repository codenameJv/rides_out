import 'package:flutter/material.dart';

import '../../local_db/models/route_point_model.dart';
import '../services/hive_service.dart';
import 'distance_calculator.dart';

class RouteSegmentUtils {
  RouteSegmentUtils._();

  static Duration get defaultGapThreshold {
    final minutes =
        HiveService.settingsBox.get('session_gap_minutes', defaultValue: 30)
            as int;
    return Duration(minutes: minutes);
  }

  /// Split a flat list of route points into segments by detecting timestamp
  /// gaps larger than [threshold] between consecutive points.
  static List<List<RoutePointModel>> splitIntoSegments(
    List<RoutePointModel> points, {
    Duration? threshold,
  }) {
    threshold ??= defaultGapThreshold;
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

  /// Calculate speed in km/h for each point (based on distance/time to next point).
  /// Returns a list with the same length as [points]. Last point gets same speed as previous.
  /// Applies 3-point moving average for GPS jitter smoothing.
  static List<double> calculateSpeeds(List<RoutePointModel> points) {
    if (points.length < 2) return List.filled(points.length, 0.0);

    // Raw speeds
    final raw = <double>[];
    for (int i = 0; i < points.length - 1; i++) {
      final dist = DistanceCalculator.distanceKm(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
      final dt = points[i + 1]
          .timestamp
          .difference(points[i].timestamp)
          .inMilliseconds;
      if (dt <= 0) {
        raw.add(0.0);
      } else {
        raw.add(dist / (dt / 3600000.0)); // km/h
      }
    }
    raw.add(raw.last); // last point

    // 3-point moving average
    final smoothed = <double>[];
    for (int i = 0; i < raw.length; i++) {
      final start = (i - 1).clamp(0, raw.length - 1);
      final end = (i + 1).clamp(0, raw.length - 1);
      double sum = 0;
      int count = 0;
      for (int j = start; j <= end; j++) {
        sum += raw[j];
        count++;
      }
      smoothed.add(sum / count);
    }

    return smoothed;
  }

  /// Map speed (km/h) to a color: green (0-40) → yellow (40-80) → red (80+).
  static Color speedColor(double kmh) {
    const green = Color(0xFF4CAF50);
    const yellow = Color(0xFFFFC107);
    const red = Color(0xFFEF5350);

    if (kmh <= 0) return green;
    if (kmh <= 40) {
      final t = kmh / 40.0;
      return Color.lerp(green, yellow, t)!;
    }
    if (kmh <= 80) {
      final t = (kmh - 40) / 40.0;
      return Color.lerp(yellow, red, t)!;
    }
    return red;
  }
}
