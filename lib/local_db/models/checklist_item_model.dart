import 'package:hive/hive.dart';
import '../../core/constants/hive_constants.dart';
import 'enums.dart';

class ChecklistItemModel {
  final String id;
  final String label;
  final ChecklistCategory category;
  final bool isChecked;

  const ChecklistItemModel({
    required this.id,
    required this.label,
    required this.category,
    this.isChecked = false,
  });

  ChecklistItemModel copyWith({
    String? id,
    String? label,
    ChecklistCategory? category,
    bool? isChecked,
  }) {
    return ChecklistItemModel(
      id: id ?? this.id,
      label: label ?? this.label,
      category: category ?? this.category,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}

class ChecklistItemModelAdapter extends TypeAdapter<ChecklistItemModel> {
  @override
  final int typeId = HiveConstants.checklistItemTypeId;

  @override
  ChecklistItemModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ChecklistItemModel(
      id: fields[0] as String,
      label: fields[1] as String,
      category: fields[2] as ChecklistCategory,
      isChecked: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ChecklistItemModel obj) {
    writer.writeByte(4);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.label);
    writer.writeByte(2);
    writer.write(obj.category);
    writer.writeByte(3);
    writer.write(obj.isChecked);
  }
}
