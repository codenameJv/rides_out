import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../../local_db/models/enums.dart';
import '../../../local_db/models/trip_model.dart';
import '../../trips/providers/trips_provider.dart';

class TripStatistics {
  final int totalTrips;
  final Map<TripStatus, int> tripsByStatus;
  final double totalMiles;
  final double totalSpent;
  final double averageDurationDays;
  final Map<StopType, int> stopTypeCounts;
  final Map<String, int> tripsPerMonth; // "2024-01" → count
  final TripModel? mostExpensiveTrip;
  final Map<ExpenseCategory, double> categorySpending;

  const TripStatistics({
    this.totalTrips = 0,
    this.tripsByStatus = const {},
    this.totalMiles = 0,
    this.totalSpent = 0,
    this.averageDurationDays = 0,
    this.stopTypeCounts = const {},
    this.tripsPerMonth = const {},
    this.mostExpensiveTrip,
    this.categorySpending = const {},
  });
}

final tripStatisticsProvider = Provider<TripStatistics>((ref) {
  final trips = ref.watch(tripsProvider);

  if (trips.isEmpty) return const TripStatistics();

  // Trips by status
  final byStatus = <TripStatus, int>{};
  for (final status in TripStatus.values) {
    final count = trips.where((t) => t.status == status).length;
    if (count > 0) byStatus[status] = count;
  }

  // Total miles
  double totalMiles = 0;
  for (final trip in trips) {
    final points = trip.stops
        .where((s) => s.location != null)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    if (points.length >= 2) {
      final coords = points
          .map((s) => (s.location!.latitude, s.location!.longitude))
          .toList();
      totalMiles += DistanceCalculator.totalDistance(coords);
    }
  }

  // Total spent
  final totalSpent = trips.fold<double>(0, (sum, t) => sum + t.totalExpenses);

  // Average duration
  double avgDuration = 0;
  if (trips.isNotEmpty) {
    final totalDays = trips.fold<int>(
        0, (sum, t) => sum + t.endDate.difference(t.startDate).inDays.clamp(1, 9999));
    avgDuration = totalDays / trips.length;
  }

  // Stop type counts
  final stopCounts = <StopType, int>{};
  for (final trip in trips) {
    for (final stop in trip.stops) {
      stopCounts[stop.type] = (stopCounts[stop.type] ?? 0) + 1;
    }
  }

  // Trips per month (last 12 months)
  final now = DateTime.now();
  final monthCounts = <String, int>{};
  for (int i = 11; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final key =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    monthCounts[key] = 0;
  }
  for (final trip in trips) {
    final key =
        '${trip.startDate.year}-${trip.startDate.month.toString().padLeft(2, '0')}';
    if (monthCounts.containsKey(key)) {
      monthCounts[key] = monthCounts[key]! + 1;
    }
  }

  // Most expensive trip
  TripModel? mostExpensive;
  if (trips.any((t) => t.totalExpenses > 0)) {
    mostExpensive = trips
        .where((t) => t.totalExpenses > 0)
        .reduce((a, b) => a.totalExpenses > b.totalExpenses ? a : b);
  }

  // Category spending
  final catSpending = <ExpenseCategory, double>{};
  for (final trip in trips) {
    for (final expense in trip.expenses) {
      catSpending[expense.category] =
          (catSpending[expense.category] ?? 0) + expense.amount;
    }
  }

  return TripStatistics(
    totalTrips: trips.length,
    tripsByStatus: byStatus,
    totalMiles: totalMiles,
    totalSpent: totalSpent,
    averageDurationDays: avgDuration,
    stopTypeCounts: stopCounts,
    tripsPerMonth: monthCounts,
    mostExpensiveTrip: mostExpensive,
    categorySpending: catSpending,
  );
});
