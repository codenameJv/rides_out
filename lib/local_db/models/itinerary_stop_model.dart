import 'package:hive/hive.dart';
import '../../core/constants/hive_constants.dart';
import 'enums.dart';
import 'geo_point_model.dart';
import 'stop_task_model.dart';

class ItineraryStopModel {
  final String id;
  final String name;
  final String? description;
  final StopType type;
  final GeoPointModel? location;
  final DateTime? arrivalTime;
  final int order;
  final List<StopTaskModel> tasks;
  final bool isDone;

  const ItineraryStopModel({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    this.location,
    this.arrivalTime,
    required this.order,
    this.tasks = const [],
    this.isDone = false,
  });

  ItineraryStopModel copyWith({
    String? id,
    String? name,
    String? description,
    StopType? type,
    GeoPointModel? location,
    DateTime? arrivalTime,
    int? order,
    List<StopTaskModel>? tasks,
    bool? isDone,
    bool clearDescription = false,
    bool clearLocation = false,
    bool clearArrivalTime = false,
  }) {
    return ItineraryStopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      type: type ?? this.type,
      location: clearLocation ? null : (location ?? this.location),
      arrivalTime:
          clearArrivalTime ? null : (arrivalTime ?? this.arrivalTime),
      order: order ?? this.order,
      tasks: tasks ?? List.from(this.tasks),
      isDone: isDone ?? this.isDone,
    );
  }
}

class ItineraryStopModelAdapter extends TypeAdapter<ItineraryStopModel> {
  @override
  final int typeId = HiveConstants.itineraryStopTypeId;

  @override
  ItineraryStopModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ItineraryStopModel(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      type: fields[3] as StopType,
      location: fields[4] as GeoPointModel?,
      arrivalTime: fields[5] as DateTime?,
      order: fields[6] as int,
      tasks: fields.containsKey(7)
          ? (fields[7] as List).cast<StopTaskModel>()
          : [],
      isDone: fields.containsKey(8) ? fields[8] as bool : false,
    );
  }

  @override
  void write(BinaryWriter writer, ItineraryStopModel obj) {
    writer.writeByte(9); // number of fields
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.description);
    writer.writeByte(3);
    writer.write(obj.type);
    writer.writeByte(4);
    writer.write(obj.location);
    writer.writeByte(5);
    writer.write(obj.arrivalTime);
    writer.writeByte(6);
    writer.write(obj.order);
    writer.writeByte(7);
    writer.write(obj.tasks);
    writer.writeByte(8);
    writer.write(obj.isDone);
  }
}
