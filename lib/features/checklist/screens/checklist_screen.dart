import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../local_db/models/enums.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../providers/checklist_provider.dart';
import '../widgets/category_section.dart';
import '../widgets/checklist_progress_bar.dart';
import '../widgets/template_selector_sheet.dart';

class ChecklistScreen extends ConsumerWidget {
  final String tripId;

  const ChecklistScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(checklistProvider(tripId));
    final byCategory = ref.watch(checklistByCategoryProvider(tripId));
    final progress = ref.watch(checklistProgressProvider(tripId));
    final actions = ref.read(checklistActionsProvider(tripId));

    if (items.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.checklist,
        title: 'Checklist is empty',
        subtitle: 'Load a template or add items manually.',
        action: ElevatedButton.icon(
          onPressed: () => _showTemplateSelector(context, actions),
          icon: const Icon(Icons.download),
          label: const Text('Load Template'),
        ),
      );
    }

    final checked = items.where((i) => i.isChecked).length;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            ChecklistProgressBar(
              progress: progress,
              total: items.length,
              checked: checked,
            ),
            ...byCategory.entries.map((entry) => CategorySection(
                  category: entry.key,
                  items: entry.value,
                  onToggle: (id) => actions.toggleItem(id),
                  onDelete: (id) => actions.deleteItem(id),
                )),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'template',
                backgroundColor: AppColors.surfaceLight,
                onPressed: () => _showTemplateSelector(context, actions),
                child:
                    const Icon(Icons.description, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'add_item',
                onPressed: () => _showAddItemDialog(context, actions),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showTemplateSelector(
      BuildContext context, ChecklistActions actions) async {
    final names = await actions.getTemplateNames();
    if (!context.mounted) return;
    TemplateSelectorSheet.show(
      context,
      templates: names,
      onSelect: (name) => actions.applyTemplate(name),
    );
  }

  void _showAddItemDialog(
      BuildContext context, ChecklistActions actions) {
    final controller = TextEditingController();
    ChecklistCategory category = ChecklistCategory.gear;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Item name',
                ),
                autofocus: true,
              ),
              const SizedBox(height: AppDimensions.paddingMD),
              DropdownButtonFormField<ChecklistCategory>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ChecklistCategory.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.label),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => category = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  actions.addItem(
                    label: controller.text.trim(),
                    category: category,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
