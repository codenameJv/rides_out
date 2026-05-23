import 'package:hive/hive.dart';
import '../../core/constants/hive_constants.dart';

class TripStatusAdapter extends TypeAdapter<TripStatus> {
  @override
  final int typeId = HiveConstants.tripStatusTypeId;

  @override
  TripStatus read(BinaryReader reader) => TripStatus.values[reader.readInt()];

  @override
  void write(BinaryWriter writer, TripStatus obj) => writer.writeInt(obj.index);
}

class StopTypeAdapter extends TypeAdapter<StopType> {
  @override
  final int typeId = HiveConstants.stopTypeTypeId;

  @override
  StopType read(BinaryReader reader) => StopType.values[reader.readInt()];

  @override
  void write(BinaryWriter writer, StopType obj) => writer.writeInt(obj.index);
}

class ExpenseCategoryAdapter extends TypeAdapter<ExpenseCategory> {
  @override
  final int typeId = HiveConstants.expenseCategoryTypeId;

  @override
  ExpenseCategory read(BinaryReader reader) =>
      ExpenseCategory.values[reader.readInt()];

  @override
  void write(BinaryWriter writer, ExpenseCategory obj) =>
      writer.writeInt(obj.index);
}

class ChecklistCategoryAdapter extends TypeAdapter<ChecklistCategory> {
  @override
  final int typeId = HiveConstants.checklistCategoryTypeId;

  @override
  ChecklistCategory read(BinaryReader reader) =>
      ChecklistCategory.values[reader.readInt()];

  @override
  void write(BinaryWriter writer, ChecklistCategory obj) =>
      writer.writeInt(obj.index);
}

enum TripStatus {
  planning,
  upcoming,
  active,
  completed;

  String get label {
    switch (this) {
      case TripStatus.planning:
        return 'Planning';
      case TripStatus.upcoming:
        return 'Upcoming';
      case TripStatus.active:
        return 'Active';
      case TripStatus.completed:
        return 'Completed';
    }
  }
}

enum StopType {
  start,
  fuel,
  food,
  scenic,
  campsite,
  lodging,
  rest,
  destination,
  other,
  waypoint,
  shapePoint;

  bool get isShapeOnly => this == StopType.shapePoint;

  String get label {
    switch (this) {
      case StopType.start:
        return 'Start';
      case StopType.fuel:
        return 'Fuel';
      case StopType.food:
        return 'Food';
      case StopType.scenic:
        return 'Scenic';
      case StopType.campsite:
        return 'Campsite';
      case StopType.lodging:
        return 'Lodging';
      case StopType.rest:
        return 'Rest';
      case StopType.destination:
        return 'Destination';
      case StopType.other:
        return 'Other';
      case StopType.waypoint:
        return 'Waypoint';
      case StopType.shapePoint:
        return 'Shape Point';
    }
  }

  String get icon {
    switch (this) {
      case StopType.start:
        return '🏁';
      case StopType.fuel:
        return '⛽';
      case StopType.food:
        return '🍔';
      case StopType.scenic:
        return '📸';
      case StopType.campsite:
        return '⛺';
      case StopType.lodging:
        return '🏨';
      case StopType.rest:
        return '☕';
      case StopType.destination:
        return '📍';
      case StopType.other:
        return '📌';
      case StopType.waypoint:
        return '◆';
      case StopType.shapePoint:
        return '·';
    }
  }
}

enum ExpenseCategory {
  fuel,
  food,
  lodging,
  camping,
  gear,
  maintenance,
  tolls,
  entertainment,
  other;

  String get label {
    switch (this) {
      case ExpenseCategory.fuel:
        return 'Fuel';
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.lodging:
        return 'Lodging';
      case ExpenseCategory.camping:
        return 'Camping';
      case ExpenseCategory.gear:
        return 'Gear';
      case ExpenseCategory.maintenance:
        return 'Maintenance';
      case ExpenseCategory.tolls:
        return 'Tolls';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.other:
        return 'Other';
    }
  }
}

enum ChecklistCategory {
  gear,
  camping,
  electronics,
  essentials,
  bikePrepare,
  other;

  String get label {
    switch (this) {
      case ChecklistCategory.gear:
        return 'Gear';
      case ChecklistCategory.camping:
        return 'Camping';
      case ChecklistCategory.electronics:
        return 'Electronics';
      case ChecklistCategory.essentials:
        return 'Essentials';
      case ChecklistCategory.bikePrepare:
        return 'Bike Prep';
      case ChecklistCategory.other:
        return 'Other';
    }
  }

  static ChecklistCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'gear':
        return ChecklistCategory.gear;
      case 'camping':
        return ChecklistCategory.camping;
      case 'electronics':
        return ChecklistCategory.electronics;
      case 'essentials':
        return ChecklistCategory.essentials;
      case 'bike_prep':
        return ChecklistCategory.bikePrepare;
      default:
        return ChecklistCategory.other;
    }
  }
}
