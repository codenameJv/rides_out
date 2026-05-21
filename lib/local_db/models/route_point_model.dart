import 'package:hive/hive.dart';
import '../../core/constants/hive_constants.dart';

class RoutePointModel {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const RoutePointModel({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  RoutePointModel copyWith({
    double? latitude,
    double? longitude,
    DateTime? timestamp,
  }) {
    return RoutePointModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutePointModel &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      latitude.hashCode ^ longitude.hashCode ^ timestamp.hashCode;
}

class RoutePointModelAdapter extends TypeAdapter<RoutePointModel> {
  @override
  final int typeId = HiveConstants.routePointTypeId;

  @override
  RoutePointModel read(BinaryReader reader) {
    return RoutePointModel(
      latitude: reader.readDouble(),
      longitude: reader.readDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, RoutePointModel obj) {
    writer.writeDouble(obj.latitude);
    writer.writeDouble(obj.longitude);
    writer.writeInt(obj.timestamp.millisecondsSinceEpoch);
  }
}
