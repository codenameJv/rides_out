import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';

class TemplateSelectorSheet extends StatelessWidget {
  final List<String> templates;
  final void Function(String name) onSelect;

  const TemplateSelectorSheet({
    super.key,
    required this.templates,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> templates,
    required void Function(String name) onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLG),
        ),
      ),
      builder: (_) => TemplateSelectorSheet(
        templates: templates,
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingMD),
          Text('Load Template', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Items not already on your list will be added.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppDimensions.paddingMD),
          ...templates.map(
            (name) => ListTile(
              leading: const Icon(Icons.description, color: AppColors.primary),
              title: Text(name),
              onTap: () {
                Navigator.pop(context);
                onSelect(name);
              },
            ),
          ),
          const SizedBox(height: AppDimensions.paddingSM),
        ],
      ),
    );
  }
}
