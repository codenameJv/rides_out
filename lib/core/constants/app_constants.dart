class AppConstants {
  AppConstants._();

  static const String appName = 'Rides Out';
  static const String appTagline = 'Plan your next adventure';

  // Splash
  static const Duration splashDuration = Duration(seconds: 2);

  // Map defaults
  static const double defaultMapZoom = 10.0;
  static const double defaultLat = 12.8797;
  static const double defaultLng = 121.7740; // Center of Philippines

  // OSM Tile URL
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmAttribution = '© OpenStreetMap contributors';

  // Expense categories
  static const List<String> expenseCategories = [
    'Fuel',
    'Food',
    'Lodging',
    'Camping',
    'Gear',
    'Maintenance',
    'Tolls',
    'Entertainment',
    'Other',
  ];

  // Checklist categories
  static const List<String> checklistCategories = [
    'gear',
    'camping',
    'electronics',
    'essentials',
    'bike_prep',
    'other',
  ];

  // Stop types
  static const List<String> stopTypes = [
    'start',
    'fuel',
    'food',
    'scenic',
    'campsite',
    'lodging',
    'rest',
    'destination',
    'other',
  ];
}
