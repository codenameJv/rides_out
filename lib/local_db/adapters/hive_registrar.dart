import 'package:hive/hive.dart';
import '../models/enums.dart';
import '../models/geo_point_model.dart';
import '../models/stop_task_model.dart';
import '../models/itinerary_stop_model.dart';
import '../models/checklist_item_model.dart';
import '../models/expense_model.dart';
import '../models/route_point_model.dart';
import '../models/trip_model.dart';

void registerHiveAdapters() {
  Hive.registerAdapter(TripStatusAdapter());
  Hive.registerAdapter(StopTypeAdapter());
  Hive.registerAdapter(ExpenseCategoryAdapter());
  Hive.registerAdapter(ChecklistCategoryAdapter());
  Hive.registerAdapter(GeoPointModelAdapter());
  Hive.registerAdapter(StopTaskModelAdapter());
  Hive.registerAdapter(ItineraryStopModelAdapter());
  Hive.registerAdapter(ChecklistItemModelAdapter());
  Hive.registerAdapter(RoutePointModelAdapter());
  Hive.registerAdapter(ExpenseModelAdapter());
  Hive.registerAdapter(TripModelAdapter());
}
