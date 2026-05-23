import 'package:flutter/material.dart';
import '../../../core/services/overpass_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';

class PoiDetailSheet extends StatelessWidget {
  final PoiModel poi;
  final VoidCallback? onAddAsStop;

  const PoiDetailSheet({
    super.key,
    required this.poi,
    this.onAddAsStop,
  });

  @override
  Widget build(BuildContext context) {
    final icon = OverpassService.categoryIcons[poi.category] ?? '\uD83D\uDCCD';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppDimensions.paddingMD),
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Name and category
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poi.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      poi.category[0].toUpperCase() +
                          poi.category.substring(1),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Tags
          if (poi.tags.containsKey('addr:street') ||
              poi.tags.containsKey('phone') ||
              poi.tags.containsKey('opening_hours'))
            Padding(
              padding:
                  const EdgeInsets.only(top: AppDimensions.paddingSM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (poi.tags['addr:street'] != null)
                    _InfoRow(
                      icon: Icons.location_on,
                      text: poi.tags['addr:street']!,
                    ),
                  if (poi.tags['phone'] != null)
                    _InfoRow(
                      icon: Icons.phone,
                      text: poi.tags['phone']!,
                    ),
                  if (poi.tags['opening_hours'] != null)
                    _InfoRow(
                      icon: Icons.schedule,
                      text: poi.tags['opening_hours']!,
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppDimensions.paddingMD),
          // Add as stop button
          if (onAddAsStop != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAddAsStop,
                icon: const Icon(Icons.add_location),
                label: const Text('Add as Stop'),
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
