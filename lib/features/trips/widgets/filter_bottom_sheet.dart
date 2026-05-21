import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../providers/trip_filter_provider.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final filter = ref.read(tripFilterProvider);
    _dateFrom = filter.dateFrom;
    _dateTo = filter.dateTo;
    if (filter.budgetMin != null) {
      _budgetMinController.text = filter.budgetMin!.toStringAsFixed(0);
    }
    if (filter.budgetMax != null) {
      _budgetMaxController.text = filter.budgetMax!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  void _apply() {
    final notifier = ref.read(tripFilterProvider.notifier);
    notifier.setDateRange(_dateFrom, _dateTo);
    notifier.setBudgetRange(
      double.tryParse(_budgetMinController.text),
      double.tryParse(_budgetMaxController.text),
    );
    Navigator.pop(context);
  }

  void _clear() {
    ref.read(tripFilterProvider.notifier).clearAll();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingLG,
        AppDimensions.paddingLG,
        AppDimensions.paddingLG,
        AppDimensions.paddingLG + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Advanced Filters', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppDimensions.paddingLG),

          // Date range
          Text('Date Range', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.paddingSM),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _dateFrom != null
                        ? DateFormatter.shortDate(_dateFrom!)
                        : 'From',
                  ),
                  onPressed: () => _pickDate(true),
                ),
              ),
              const SizedBox(width: AppDimensions.paddingSM),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _dateTo != null
                        ? DateFormatter.shortDate(_dateTo!)
                        : 'To',
                  ),
                  onPressed: () => _pickDate(false),
                ),
              ),
              if (_dateFrom != null || _dateTo != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() {
                    _dateFrom = null;
                    _dateTo = null;
                  }),
                ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingMD),

          // Budget range
          Text('Budget Range', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.paddingSM),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _budgetMinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: '\u20B1 ',
                    hintText: 'Min',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.paddingSM),
              Expanded(
                child: TextField(
                  controller: _budgetMaxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: '\u20B1 ',
                    hintText: 'Max',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingLG),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clear,
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: AppDimensions.paddingSM),
              Expanded(
                child: FilledButton(
                  onPressed: _apply,
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
