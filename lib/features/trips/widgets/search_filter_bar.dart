import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../local_db/models/enums.dart';
import '../providers/trip_filter_provider.dart';
import 'filter_bottom_sheet.dart';

class SearchFilterBar extends ConsumerStatefulWidget {
  const SearchFilterBar({super.key});

  @override
  ConsumerState<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends ConsumerState<SearchFilterBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(tripFilterProvider).searchQuery,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(tripFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        AppDimensions.paddingSM,
        AppDimensions.paddingMD,
        0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Search trips...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _controller.clear();
                              ref
                                  .read(tripFilterProvider.notifier)
                                  .setSearchQuery('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingSM,
                      vertical: AppDimensions.paddingSM,
                    ),
                  ),
                  onChanged: (value) {
                    ref.read(tripFilterProvider.notifier).setSearchQuery(value);
                  },
                ),
              ),
              const SizedBox(width: AppDimensions.paddingSM),
              IconButton(
                icon: Icon(
                  Icons.tune,
                  color: (filter.dateFrom != null ||
                          filter.dateTo != null ||
                          filter.budgetMin != null ||
                          filter.budgetMax != null)
                      ? AppColors.primary
                      : null,
                ),
                tooltip: 'Advanced Filters',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const FilterBottomSheet(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingSM),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: TripStatus.values.map((status) {
                final selected = filter.statusFilters.contains(status);
                return Padding(
                  padding: const EdgeInsets.only(right: AppDimensions.paddingXS),
                  child: FilterChip(
                    label: Text(status.label),
                    selected: selected,
                    onSelected: (_) {
                      ref
                          .read(tripFilterProvider.notifier)
                          .toggleStatus(status);
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.3),
                    checkmarkColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
