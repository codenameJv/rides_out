import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../local_db/models/enums.dart';
import '../providers/expenses_provider.dart';
import '../../trips/providers/trips_provider.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String? expenseId;

  const ExpenseFormScreen({super.key, required this.tripId, this.expenseId});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descController;
  late TextEditingController _amountController;
  ExpenseCategory _category = ExpenseCategory.fuel;
  late DateTime _date;

  bool get isEditing => widget.expenseId != null;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController();
    _amountController = TextEditingController();
    _date = DateTime.now();

    if (isEditing) {
      final trip = ref.read(tripByIdProvider(widget.tripId));
      if (trip != null) {
        try {
          final expense =
              trip.expenses.firstWhere((e) => e.id == widget.expenseId);
          _descController.text = expense.description;
          _amountController.text = expense.amount.toStringAsFixed(2);
          _category = expense.category;
          _date = expense.date;
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0;
    final actions = ref.read(expenseActionsProvider(widget.tripId));

    if (isEditing) {
      final trip = ref.read(tripByIdProvider(widget.tripId));
      if (trip != null) {
        try {
          final expense =
              trip.expenses.firstWhere((e) => e.id == widget.expenseId);
          await actions.updateExpense(expense.copyWith(
            description: _descController.text.trim(),
            amount: amount,
            category: _category,
            date: _date,
          ));
        } catch (_) {}
      }
    } else {
      await actions.addExpense(
        description: _descController.text.trim(),
        amount: amount,
        category: _category,
        date: _date,
      );
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Expense' : 'Add Expense'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          children: [
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Gas at Shell station',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Description is required' : null,
            ),
            const SizedBox(height: AppDimensions.paddingMD),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₱ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Amount is required';
                if (double.tryParse(v) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.paddingMD),
            DropdownButtonFormField<ExpenseCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ExpenseCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.label),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: AppDimensions.paddingMD),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Text(
                  DateFormatter.fullDate(_date),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
