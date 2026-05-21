import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../providers/trips_provider.dart';
import '../../../local_db/models/enums.dart';

class TripFormScreen extends ConsumerStatefulWidget {
  final String? tripId;

  const TripFormScreen({super.key, this.tripId});

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _budgetController;
  late DateTime _startDate;
  late DateTime _endDate;
  TripStatus _status = TripStatus.planning;

  bool get isEditing => widget.tripId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _budgetController = TextEditingController();
    _startDate = DateTime.now().add(const Duration(days: 7));
    _endDate = DateTime.now().add(const Duration(days: 9));

    if (isEditing) {
      final trip = ref.read(tripsProvider.notifier).getTrip(widget.tripId!);
      if (trip != null) {
        _nameController.text = trip.name;
        _descController.text = trip.description ?? '';
        _budgetController.text =
            trip.budget > 0 ? trip.budget.toStringAsFixed(0) : '';
        _startDate = trip.startDate;
        _endDate = trip.endDate;
        _status = trip.status;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final budget = double.tryParse(_budgetController.text) ?? 0;
    final notifier = ref.read(tripsProvider.notifier);

    if (isEditing) {
      final trip = notifier.getTrip(widget.tripId!);
      if (trip != null) {
        trip.name = _nameController.text.trim();
        trip.description = _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null;
        trip.startDate = _startDate;
        trip.endDate = _endDate;
        trip.budget = budget;
        trip.status = _status;
        await notifier.updateTrip(trip);
      }
    } else {
      await notifier.createTrip(
        name: _nameController.text.trim(),
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        startDate: _startDate,
        endDate: _endDate,
        budget: budget,
      );
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Trip' : 'Plan a Ride'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Trip Name',
                hintText: 'e.g., Blue Ridge Parkway',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: AppDimensions.paddingMD),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add notes about your trip...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppDimensions.paddingMD),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Start Date',
                    date: _startDate,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: AppDimensions.paddingMD),
                Expanded(
                  child: _DateField(
                    label: 'End Date',
                    date: _endDate,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMD),
            TextFormField(
              controller: _budgetController,
              decoration: const InputDecoration(
                labelText: 'Budget (optional)',
                hintText: '0.00',
                prefixText: '₱ ',
              ),
              keyboardType: TextInputType.number,
            ),
            if (isEditing) ...[
              const SizedBox(height: AppDimensions.paddingMD),
              DropdownButtonFormField<TripStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: TripStatus.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.label),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          DateFormatter.fullDate(date),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
