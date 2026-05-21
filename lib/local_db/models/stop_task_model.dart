import 'package:hive/hive.dart';
import '../../core/constants/hive_constants.dart';

class StopTaskModel {
  final String id;
  final String label;
  final bool isChecked;

  const StopTaskModel({
    required this.id,
    required this.label,
    this.isChecked = false,
  });

  StopTaskModel copyWith({
    String? id,
    String? label,
    bool? isChecked,
  }) {
    return StopTaskModel(
      id: id ?? this.id,
      label: label ?? this.label,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}

class StopTaskModelAdapter extends TypeAdapter<StopTaskModel> {
  @override
  final int typeId = HiveConstants.stopTaskTypeId;

  @override
  StopTaskModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return StopTaskModel(
      id: fields[0] as String,
      label: fields[1] as String,
      isChecked: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, StopTaskModel obj) {
    writer.writeByte(3);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.label);
    writer.writeByte(2);
    writer.write(obj.isChecked);
  }
}
