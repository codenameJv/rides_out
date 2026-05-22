import 'package:hive/hive.dart';
import '../../core/constants/hive_constants.dart';
import 'enums.dart';
import 'itinerary_stop_model.dart';
import 'checklist_item_model.dart';
import 'expense_model.dart';
import 'route_point_model.dart';

class TripModel extends HiveObject {
  final String id;
  String name;
  String? description;
  TripStatus status;
  DateTime startDate;
  DateTime endDate;
  double budget;
  List<ItineraryStopModel> stops;
  List<ChecklistItemModel> checklist;
  List<ExpenseModel> expenses;
  DateTime createdAt;
  DateTime updatedAt;
  List<RoutePointModel> recordedRoute;

  TripModel({
    required this.id,
    required this.name,
    this.description,
    this.status = TripStatus.planning,
    required this.startDate,
    required this.endDate,
    this.budget = 0,
    List<ItineraryStopModel>? stops,
    List<ChecklistItemModel>? checklist,
    List<ExpenseModel>? expenses,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<RoutePointModel>? recordedRoute,
  })  : stops = stops ?? [],
        checklist = checklist ?? [],
        expenses = expenses ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        recordedRoute = recordedRoute ?? [];

  bool get hasRecordedRoute => recordedRoute.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'status': status.name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'budget': budget,
        'stops': stops.map((s) => s.toJson()).toList(),
        'checklist': checklist.map((c) => c.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'recordedRoute': recordedRoute.map((r) => r.toJson()).toList(),
      };

  factory TripModel.fromJson(Map<String, dynamic> json) => TripModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        status: TripStatus.values.byName(json['status'] as String),
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        budget: (json['budget'] as num).toDouble(),
        stops: (json['stops'] as List<dynamic>?)
                ?.map((s) =>
                    ItineraryStopModel.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        checklist: (json['checklist'] as List<dynamic>?)
                ?.map((c) =>
                    ChecklistItemModel.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        expenses: (json['expenses'] as List<dynamic>?)
                ?.map(
                    (e) => ExpenseModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        recordedRoute: (json['recordedRoute'] as List<dynamic>?)
                ?.map((r) =>
                    RoutePointModel.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
      );

  TripModel copyWith({
    String? id,
    String? name,
    String? description,
    TripStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    List<ItineraryStopModel>? stops,
    List<ChecklistItemModel>? checklist,
    List<ExpenseModel>? expenses,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<RoutePointModel>? recordedRoute,
    bool clearDescription = false,
  }) {
    return TripModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      stops: stops ?? List.from(this.stops),
      checklist: checklist ?? List.from(this.checklist),
      expenses: expenses ?? List.from(this.expenses),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      recordedRoute: recordedRoute ?? List.from(this.recordedRoute),
    );
  }

  double get totalExpenses =>
      expenses.fold(0, (sum, e) => sum + e.amount);

  double get remainingBudget => budget - totalExpenses;

  int get checklistProgress {
    if (checklist.isEmpty) return 0;
    final checked = checklist.where((c) => c.isChecked).length;
    return ((checked / checklist.length) * 100).round();
  }
}

class TripModelAdapter extends TypeAdapter<TripModel> {
  @override
  final int typeId = HiveConstants.tripTypeId;

  @override
  TripModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return TripModel(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      status: fields[3] as TripStatus,
      startDate: fields[4] as DateTime,
      endDate: fields[5] as DateTime,
      budget: fields[6] as double,
      stops: (fields[7] as List).cast<ItineraryStopModel>(),
      checklist: (fields[8] as List).cast<ChecklistItemModel>(),
      expenses: (fields[9] as List).cast<ExpenseModel>(),
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
      recordedRoute: fields.containsKey(12)
          ? (fields[12] as List).cast<RoutePointModel>()
          : [],
    );
  }

  @override
  void write(BinaryWriter writer, TripModel obj) {
    writer.writeByte(13);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.description);
    writer.writeByte(3);
    writer.write(obj.status);
    writer.writeByte(4);
    writer.write(obj.startDate);
    writer.writeByte(5);
    writer.write(obj.endDate);
    writer.writeByte(6);
    writer.write(obj.budget);
    writer.writeByte(7);
    writer.write(obj.stops);
    writer.writeByte(8);
    writer.write(obj.checklist);
    writer.writeByte(9);
    writer.write(obj.expenses);
    writer.writeByte(10);
    writer.write(obj.createdAt);
    writer.writeByte(11);
    writer.write(obj.updatedAt);
    writer.writeByte(12);
    writer.write(obj.recordedRoute);
  }
}
