import 'package:hive_flutter/hive_flutter.dart';
import '../../local_db/adapters/hive_registrar.dart';
import '../../local_db/models/trip_model.dart';
import '../constants/hive_constants.dart';

class HiveService {
  static late Box<TripModel> _tripsBox;
  static late Box _settingsBox;

  static Box<TripModel> get tripsBox => _tripsBox;
  static Box get settingsBox => _settingsBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    registerHiveAdapters();
    _tripsBox = await Hive.openBox<TripModel>(HiveConstants.tripsBox);
    _settingsBox = await Hive.openBox(HiveConstants.settingsBox);
  }

  static Future<void> close() async {
    await Hive.close();
  }
}
