import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../trips/providers/trips_provider.dart';

enum EfficiencyUnit { kmpl, mpg }

enum FuelPriceUnit { liter, gallon }

class BikeSettings {
  final double efficiency;
  final EfficiencyUnit efficiencyUnit;
  final double fuelPrice;
  final FuelPriceUnit priceUnit;

  const BikeSettings({
    this.efficiency = 0,
    this.efficiencyUnit = EfficiencyUnit.kmpl,
    this.fuelPrice = 0,
    this.priceUnit = FuelPriceUnit.liter,
  });

  BikeSettings copyWith({
    double? efficiency,
    EfficiencyUnit? efficiencyUnit,
    double? fuelPrice,
    FuelPriceUnit? priceUnit,
  }) {
    return BikeSettings(
      efficiency: efficiency ?? this.efficiency,
      efficiencyUnit: efficiencyUnit ?? this.efficiencyUnit,
      fuelPrice: fuelPrice ?? this.fuelPrice,
      priceUnit: priceUnit ?? this.priceUnit,
    );
  }
}

class BikeSettingsNotifier extends StateNotifier<BikeSettings> {
  BikeSettingsNotifier() : super(const BikeSettings()) {
    _load();
  }

  void _load() {
    final box = HiveService.settingsBox;
    state = BikeSettings(
      efficiency: (box.get('bikeEfficiency') as num?)?.toDouble() ?? 0,
      efficiencyUnit: EfficiencyUnit
          .values[(box.get('bikeEfficiencyUnit') as int?) ?? 0],
      fuelPrice: (box.get('fuelPrice') as num?)?.toDouble() ?? 0,
      priceUnit:
          FuelPriceUnit.values[(box.get('fuelPriceUnit') as int?) ?? 0],
    );
  }

  Future<void> update(BikeSettings settings) async {
    final box = HiveService.settingsBox;
    await box.put('bikeEfficiency', settings.efficiency);
    await box.put('bikeEfficiencyUnit', settings.efficiencyUnit.index);
    await box.put('fuelPrice', settings.fuelPrice);
    await box.put('fuelPriceUnit', settings.priceUnit.index);
    state = settings;
  }
}

final bikeSettingsProvider =
    StateNotifierProvider<BikeSettingsNotifier, BikeSettings>((ref) {
  return BikeSettingsNotifier();
});

class FuelEstimate {
  final double distanceMiles;
  final double distanceKm;
  final double fuelNeeded;
  final double totalCost;
  final FuelPriceUnit fuelUnit;

  const FuelEstimate({
    required this.distanceMiles,
    required this.distanceKm,
    required this.fuelNeeded,
    required this.totalCost,
    required this.fuelUnit,
  });
}

final fuelEstimateProvider =
    Provider.family<FuelEstimate?, String>((ref, tripId) {
  final trip = ref.watch(tripByIdProvider(tripId));
  final settings = ref.watch(bikeSettingsProvider);

  if (trip == null || settings.efficiency <= 0) return null;

  final points = trip.stops
      .where((s) => s.location != null)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  if (points.length < 2) return null;

  final coords = points
      .map((s) => (s.location!.latitude, s.location!.longitude))
      .toList();
  final miles = DistanceCalculator.totalDistance(coords);
  final km = miles * 1.60934;

  double fuelNeeded;
  if (settings.efficiencyUnit == EfficiencyUnit.kmpl) {
    fuelNeeded = km / settings.efficiency;
  } else {
    fuelNeeded = miles / settings.efficiency;
  }

  double totalCost;
  if (settings.priceUnit == FuelPriceUnit.liter) {
    final litersNeeded = settings.efficiencyUnit == EfficiencyUnit.kmpl
        ? fuelNeeded
        : fuelNeeded * 3.78541;
    totalCost = litersNeeded * settings.fuelPrice;
  } else {
    final gallonsNeeded = settings.efficiencyUnit == EfficiencyUnit.mpg
        ? fuelNeeded
        : fuelNeeded / 3.78541;
    totalCost = gallonsNeeded * settings.fuelPrice;
  }

  return FuelEstimate(
    distanceMiles: miles,
    distanceKm: km,
    fuelNeeded: fuelNeeded,
    totalCost: totalCost,
    fuelUnit: settings.priceUnit,
  );
});
