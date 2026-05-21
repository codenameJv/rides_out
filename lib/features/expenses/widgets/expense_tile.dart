import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../local_db/models/expense_model.dart';
import '../../../local_db/models/enums.dart';

class ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.expenseCategoryColor(expense.category.name);
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.error.withValues(alpha: 0.2),
        child: const Icon(Icons.delete, color: AppColors.error),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
          ),
          child: Icon(
            _categoryIcon(expense.category),
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          expense.description,
          style: AppTextStyles.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${expense.category.label} · ${DateFormatter.shortDate(expense.date)}',
          style: AppTextStyles.bodySmall,
        ),
        trailing: Text(
          CurrencyFormatter.format(expense.amount),
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }

  IconData _categoryIcon(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.fuel:
        return Icons.local_gas_station;
      case ExpenseCategory.food:
        return Icons.restaurant;
      case ExpenseCategory.lodging:
        return Icons.hotel;
      case ExpenseCategory.camping:
        return Icons.park;
      case ExpenseCategory.gear:
        return Icons.construction;
      case ExpenseCategory.maintenance:
        return Icons.build;
      case ExpenseCategory.tolls:
        return Icons.toll;
      case ExpenseCategory.entertainment:
        return Icons.celebration;
      case ExpenseCategory.other:
        return Icons.receipt;
    }
  }
}
