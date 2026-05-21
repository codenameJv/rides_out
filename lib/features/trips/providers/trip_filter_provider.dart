import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../local_db/models/enums.dart';
import '../../../local_db/models/trip_model.dart';
import 'trips_provider.dart';

class TripFilterState {
  final String searchQuery;
  final Set<TripStatus> statusFilters;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? budgetMin;
  final double? budgetMax;

  const TripFilterState({
    this.searchQuery = '',
    this.statusFilters = const {},
    this.dateFrom,
    this.dateTo,
    this.budgetMin,
    this.budgetMax,
  });

  bool get isActive =>
      searchQuery.isNotEmpty ||
      statusFilters.isNotEmpty ||
      dateFrom != null ||
      dateTo != null ||
      budgetMin != null ||
      budgetMax != null;

  TripFilterState copyWith({
    String? searchQuery,
    Set<TripStatus>? statusFilters,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? budgetMin,
    double? budgetMax,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearBudgetMin = false,
    bool clearBudgetMax = false,
  }) {
    return TripFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilters: statusFilters ?? this.statusFilters,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      budgetMin: clearBudgetMin ? null : (budgetMin ?? this.budgetMin),
      budgetMax: clearBudgetMax ? null : (budgetMax ?? this.budgetMax),
    );
  }
}

class TripFilterNotifier extends StateNotifier<TripFilterState> {
  TripFilterNotifier() : super(const TripFilterState());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleStatus(TripStatus status) {
    final current = Set<TripStatus>.from(state.statusFilters);
    if (current.contains(status)) {
      current.remove(status);
    } else {
      current.add(status);
    }
    state = state.copyWith(statusFilters: current);
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(
      dateFrom: from,
      dateTo: to,
      clearDateFrom: from == null,
      clearDateTo: to == null,
    );
  }

  void setBudgetRange(double? min, double? max) {
    state = state.copyWith(
      budgetMin: min,
      budgetMax: max,
      clearBudgetMin: min == null,
      clearBudgetMax: max == null,
    );
  }

  void clearAll() {
    state = const TripFilterState();
  }
}

final tripFilterProvider =
    StateNotifierProvider<TripFilterNotifier, TripFilterState>((ref) {
  return TripFilterNotifier();
});

final searchVisibleProvider = StateProvider<bool>((ref) => false);

final filteredTripsProvider = Provider<List<TripModel>>((ref) {
  final trips = ref.watch(tripsProvider);
  final filter = ref.watch(tripFilterProvider);

  if (!filter.isActive) return [];

  var result = trips.toList();

  if (filter.searchQuery.isNotEmpty) {
    final query = filter.searchQuery.toLowerCase();
    result = result.where((t) {
      return t.name.toLowerCase().contains(query) ||
          (t.description?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  if (filter.statusFilters.isNotEmpty) {
    result = result.where((t) => filter.statusFilters.contains(t.status)).toList();
  }

  if (filter.dateFrom != null) {
    result = result.where((t) => !t.endDate.isBefore(filter.dateFrom!)).toList();
  }

  if (filter.dateTo != null) {
    result = result.where((t) => !t.startDate.isAfter(filter.dateTo!)).toList();
  }

  if (filter.budgetMin != null) {
    result = result.where((t) => t.budget >= filter.budgetMin!).toList();
  }

  if (filter.budgetMax != null) {
    result = result.where((t) => t.budget <= filter.budgetMax!).toList();
  }

  result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return result;
});
