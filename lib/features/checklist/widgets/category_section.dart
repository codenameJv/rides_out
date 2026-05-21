import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../local_db/models/checklist_item_model.dart';
import '../../../local_db/models/enums.dart';
import 'checklist_tile.dart';

class CategorySection extends StatelessWidget {
  final ChecklistCategory category;
  final List<ChecklistItemModel> items;
  final void Function(String itemId) onToggle;
  final void Function(String itemId) onDelete;

  const CategorySection({
    super.key,
    required this.category,
    required this.items,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final checked = items.where((i) => i.isChecked).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMD,
            vertical: AppDimensions.paddingSM,
          ),
          child: Row(
            children: [
              Text(category.label, style: AppTextStyles.titleMedium),
              const SizedBox(width: 8),
              Text(
                '$checked/${items.length}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: checked == items.length
                      ? AppColors.success
                      : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => ChecklistTile(
              item: item,
              onToggle: () => onToggle(item.id),
              onDelete: () => onDelete(item.id),
            )),
      ],
    );
  }
}
