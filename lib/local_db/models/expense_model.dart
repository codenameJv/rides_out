import 'package:hive/hive.dart';
import '../../core/constants/hive_constants.dart';
import 'enums.dart';

class ExpenseModel {
  final String id;
  final String description;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;

  const ExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amount': amount,
        'category': category.name,
        'date': date.toIso8601String(),
      };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
        id: json['id'] as String,
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: ExpenseCategory.values.byName(json['category'] as String),
        date: DateTime.parse(json['date'] as String),
      );

  ExpenseModel copyWith({
    String? id,
    String? description,
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
    );
  }
}

class ExpenseModelAdapter extends TypeAdapter<ExpenseModel> {
  @override
  final int typeId = HiveConstants.expenseTypeId;

  @override
  ExpenseModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ExpenseModel(
      id: fields[0] as String,
      description: fields[1] as String,
      amount: fields[2] as double,
      category: fields[3] as ExpenseCategory,
      date: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseModel obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.description);
    writer.writeByte(2);
    writer.write(obj.amount);
    writer.writeByte(3);
    writer.write(obj.category);
    writer.writeByte(4);
    writer.write(obj.date);
  }
}
