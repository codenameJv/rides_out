import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/id_generator.dart';
import '../../../local_db/models/expense_model.dart';
import '../../../local_db/models/enums.dart';
import '../../trips/providers/trips_provider.dart';

final expensesProvider =
    Provider.family<List<ExpenseModel>, String>((ref, tripId) {
  final trip = ref.watch(tripByIdProvider(tripId));
  if (trip == null) return [];
  return List.from(trip.expenses)
    ..sort((a, b) => b.date.compareTo(a.date));
});

final totalExpensesProvider = Provider.family<double, String>((ref, tripId) {
  final expenses = ref.watch(expensesProvider(tripId));
  return expenses.fold(0, (sum, e) => sum + e.amount);
});

final expensesByCategoryProvider =
    Provider.family<Map<ExpenseCategory, double>, String>((ref, tripId) {
  final expenses = ref.watch(expensesProvider(tripId));
  final map = <ExpenseCategory, double>{};
  for (final e in expenses) {
    map[e.category] = (map[e.category] ?? 0) + e.amount;
  }
  return map;
});

final expenseActionsProvider =
    Provider.family<ExpenseActions, String>((ref, tripId) {
  return ExpenseActions(ref, tripId);
});

class ExpenseActions {
  final Ref _ref;
  final String _tripId;

  ExpenseActions(this._ref, this._tripId);

  Future<void> addExpense({
    required String description,
    required double amount,
    required ExpenseCategory category,
    DateTime? date,
  }) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final newExpense = ExpenseModel(
      id: IdGenerator.generate(),
      description: description,
      amount: amount,
      category: category,
      date: date ?? DateTime.now(),
    );
    final updatedTrip = trip.copyWith(expenses: [...trip.expenses, newExpense]);
    await notifier.updateTrip(updatedTrip);
  }

  Future<void> updateExpense(ExpenseModel updated) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final index = trip.expenses.indexWhere((e) => e.id == updated.id);
    if (index == -1) return;

    final updatedExpenses = List<ExpenseModel>.from(trip.expenses);
    updatedExpenses[index] = updated;
    final updatedTrip = trip.copyWith(expenses: updatedExpenses);
    await notifier.updateTrip(updatedTrip);
  }

  Future<void> deleteExpense(String expenseId) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final updatedExpenses = trip.expenses.where((e) => e.id != expenseId).toList();
    final updatedTrip = trip.copyWith(expenses: updatedExpenses);
    await notifier.updateTrip(updatedTrip);
  }
}
