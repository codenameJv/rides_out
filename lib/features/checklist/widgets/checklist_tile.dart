import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../local_db/models/checklist_item_model.dart';

class ChecklistTile extends StatelessWidget {
  final ChecklistItemModel item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const ChecklistTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.error.withValues(alpha: 0.2),
        child: const Icon(Icons.delete, color: AppColors.error),
      ),
      child: ListTile(
        leading: Checkbox(
          value: item.isChecked,
          onChanged: (_) => onToggle(),
          activeColor: AppColors.primary,
          checkColor: Colors.black,
        ),
        title: Text(
          item.label,
          style: item.isChecked
              ? AppTextStyles.bodyLarge.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: AppColors.textHint,
                )
              : AppTextStyles.bodyLarge,
        ),
        dense: true,
      ),
    );
  }
}
