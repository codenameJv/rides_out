import 'package:hive/hive.dart';
import '../../core/constants/hive_constants.dart';

class GeoPointModel {
  final double latitude;
  final double longitude;

  const GeoPointModel({
    required this.latitude,
    required this.longitude,
  });

  GeoPointModel copyWith({double? latitude, double? longitude}) {
    return GeoPointModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPointModel &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

class GeoPointModelAdapter extends TypeAdapter<GeoPointModel> {
  @override
  final int typeId = HiveConstants.geoPointTypeId;

  @override
  GeoPointModel read(BinaryReader reader) {
    return GeoPointModel(
      latitude: reader.readDouble(),
      longitude: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, GeoPointModel obj) {
    writer.writeDouble(obj.latitude);
    writer.writeDouble(obj.longitude);
  }
}
