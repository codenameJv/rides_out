import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../providers/expenses_provider.dart';
import '../../trips/providers/trips_provider.dart';
import '../widgets/expense_summary_card.dart';
import '../widgets/category_chart.dart';
import '../widgets/expense_tile.dart';

class ExpensesScreen extends ConsumerWidget {
  final String tripId;

  const ExpensesScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider(tripId));
    final total = ref.watch(totalExpensesProvider(tripId));
    final byCategory = ref.watch(expensesByCategoryProvider(tripId));
    final trip = ref.watch(tripByIdProvider(tripId));
    final actions = ref.read(expenseActionsProvider(tripId));

    if (expenses.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.attach_money,
        title: 'No expenses yet',
        subtitle: 'Track your spending for this trip.',
        action: ElevatedButton.icon(
          onPressed: () => context.push('/trip/$tripId/expense/new'),
          icon: const Icon(Icons.add),
          label: const Text('Add Expense'),
        ),
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            ExpenseSummaryCard(
              totalSpent: total,
              budget: trip?.budget ?? 0,
            ),
            const SizedBox(height: AppDimensions.paddingSM),
            CategoryChart(data: byCategory, total: total),
            const SizedBox(height: AppDimensions.paddingMD),
            ...expenses.map((e) => ExpenseTile(
                  expense: e,
                  onTap: () =>
                      context.push('/trip/$tripId/expense/${e.id}'),
                  onDelete: () => actions.deleteExpense(e.id),
                )),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_expense',
            onPressed: () => context.push('/trip/$tripId/expense/new'),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
