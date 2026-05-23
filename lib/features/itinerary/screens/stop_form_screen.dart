import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/id_generator.dart';
import '../../../local_db/models/enums.dart';
import '../../../local_db/models/geo_point_model.dart';
import '../../../local_db/models/stop_task_model.dart';
import '../providers/itinerary_provider.dart';
import '../../trips/providers/trips_provider.dart';
import '../../maps/screens/location_picker_screen.dart';

class StopFormScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String? stopId;

  const StopFormScreen({super.key, required this.tripId, this.stopId});

  @override
  ConsumerState<StopFormScreen> createState() => _StopFormScreenState();
}

class _StopFormScreenState extends ConsumerState<StopFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _taskController;
  StopType _type = StopType.destination;
  DateTime? _arrivalTime;
  GeoPointModel? _selectedLocation;
  List<StopTaskModel> _tasks = [];

  bool get isEditing => widget.stopId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _taskController = TextEditingController();

    if (isEditing) {
      final trip = ref.read(tripByIdProvider(widget.tripId));
      if (trip != null) {
        try {
          final stop = trip.stops.firstWhere((s) => s.id == widget.stopId);
          _nameController.text = stop.name;
          _descController.text = stop.description ?? '';
          _type = stop.type;
          _arrivalTime = stop.arrivalTime;
          _selectedLocation = stop.location;
          _tasks = List.from(stop.tasks);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  void _addTask() {
    final label = _taskController.text.trim();
    if (label.isEmpty) return;
    setState(() {
      _tasks.add(StopTaskModel(
        id: IdGenerator.generate(),
        label: label,
      ));
      _taskController.clear();
    });
  }

  Future<void> _pickArrivalTime() async {
    final trip = ref.read(tripByIdProvider(widget.tripId));
    final date = await showDatePicker(
      context: context,
      initialDate: _arrivalTime ?? trip?.startDate ?? DateTime.now(),
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
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay.fromDateTime(_arrivalTime ?? DateTime.now()),
      );
      setState(() {
        _arrivalTime = DateTime(
          date.year,
          date.month,
          date.day,
          time?.hour ?? 12,
          time?.minute ?? 0,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final actions = ref.read(itineraryActionsProvider(widget.tripId));

    if (isEditing) {
      final trip = ref.read(tripByIdProvider(widget.tripId));
      if (trip != null) {
        try {
          final stop = trip.stops.firstWhere((s) => s.id == widget.stopId);
          await actions.updateStop(stop.copyWith(
            name: _nameController.text.trim(),
            description: _descController.text.trim().isNotEmpty
                ? _descController.text.trim()
                : null,
            type: _type,
            location: _selectedLocation,
            arrivalTime: _arrivalTime,
            tasks: _tasks,
            clearDescription: _descController.text.trim().isEmpty,
            clearLocation: _selectedLocation == null,
            clearArrivalTime: _arrivalTime == null,
          ));
        } catch (_) {}
      }
    } else {
      await actions.addStop(
        name: _nameController.text.trim(),
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        type: _type,
        location: _selectedLocation,
        arrivalTime: _arrivalTime,
        tasks: _tasks,
      );
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Stop' : 'Add Stop'),
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
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Stop Name',
                hintText: 'e.g., Tail of the Dragon',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: AppDimensions.paddingMD),
            DropdownButtonFormField<StopType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Stop Type'),
              items: StopType.values
                  .where((t) => t != StopType.waypoint && t != StopType.shapePoint)
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text('${t.icon}  ${t.label}'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            const SizedBox(height: AppDimensions.paddingMD),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppDimensions.paddingMD),
            InkWell(
              onTap: _pickArrivalTime,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Arrival Time (optional)',
                ),
                child: Text(
                  _arrivalTime != null
                      ? '${_arrivalTime!.month}/${_arrivalTime!.day}/${_arrivalTime!.year} ${_arrivalTime!.hour}:${_arrivalTime!.minute.toString().padLeft(2, '0')}'
                      : 'Tap to set',
                  style: TextStyle(
                    color: _arrivalTime != null
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMD),
            InkWell(
              onTap: () async {
                final stops = ref.read(itineraryProvider(widget.tripId));
                final result = await Navigator.push<GeoPointModel>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationPickerScreen(
                      initialLocation: _selectedLocation,
                      existingStops: stops,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() => _selectedLocation = result);
                }
              },
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Location (optional)',
                  suffixIcon: _selectedLocation != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () =>
                              setState(() => _selectedLocation = null),
                        )
                      : const Icon(Icons.map, size: 20),
                ),
                child: Text(
                  _selectedLocation != null
                      ? '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}'
                      : 'Tap to pick on map',
                  style: TextStyle(
                    color: _selectedLocation != null
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingLG),
            Text('Tasks', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppDimensions.paddingSM),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      hintText: 'Add a task...',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                  onPressed: _addTask,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingSM),
            ..._tasks.asMap().entries.map((entry) {
              final task = entry.value;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.task_alt,
                    size: 20, color: AppColors.textSecondary),
                title: Text(task.label),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() => _tasks.removeAt(entry.key));
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
