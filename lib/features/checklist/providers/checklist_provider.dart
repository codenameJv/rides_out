import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../core/utils/id_generator.dart';
import '../../../local_db/models/checklist_item_model.dart';
import '../../../local_db/models/enums.dart';
import '../../trips/providers/trips_provider.dart';

final checklistProvider =
    Provider.family<List<ChecklistItemModel>, String>((ref, tripId) {
  final trip = ref.watch(tripByIdProvider(tripId));
  if (trip == null) return [];
  return List.from(trip.checklist);
});

final checklistProgressProvider = Provider.family<double, String>((ref, tripId) {
  final items = ref.watch(checklistProvider(tripId));
  if (items.isEmpty) return 0;
  return items.where((i) => i.isChecked).length / items.length;
});

final checklistByCategoryProvider =
    Provider.family<Map<ChecklistCategory, List<ChecklistItemModel>>, String>(
        (ref, tripId) {
  final items = ref.watch(checklistProvider(tripId));
  final map = <ChecklistCategory, List<ChecklistItemModel>>{};
  for (final item in items) {
    map.putIfAbsent(item.category, () => []).add(item);
  }
  return map;
});

final checklistActionsProvider =
    Provider.family<ChecklistActions, String>((ref, tripId) {
  return ChecklistActions(ref, tripId);
});

class ChecklistActions {
  final Ref _ref;
  final String _tripId;

  ChecklistActions(this._ref, this._tripId);

  Future<void> addItem({
    required String label,
    required ChecklistCategory category,
  }) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final newItem = ChecklistItemModel(
      id: IdGenerator.generate(),
      label: label,
      category: category,
    );
    final updatedTrip = trip.copyWith(checklist: [...trip.checklist, newItem]);
    await notifier.updateTrip(updatedTrip);
  }

  Future<void> toggleItem(String itemId) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final index = trip.checklist.indexWhere((i) => i.id == itemId);
    if (index == -1) return;

    final updatedChecklist = List<ChecklistItemModel>.from(trip.checklist);
    updatedChecklist[index] = updatedChecklist[index].copyWith(
      isChecked: !updatedChecklist[index].isChecked,
    );
    final updatedTrip = trip.copyWith(checklist: updatedChecklist);
    await notifier.updateTrip(updatedTrip);
  }

  Future<void> deleteItem(String itemId) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final updatedChecklist = trip.checklist.where((i) => i.id != itemId).toList();
    final updatedTrip = trip.copyWith(checklist: updatedChecklist);
    await notifier.updateTrip(updatedTrip);
  }

  Future<void> applyTemplate(String templateName) async {
    final notifier = _ref.read(tripsProvider.notifier);
    final trip = notifier.getTrip(_tripId);
    if (trip == null) return;

    final jsonStr = await rootBundle.loadString(AssetPaths.defaultChecklist);
    final data = json.decode(jsonStr);
    final templates = data['templates'] as List;

    final template = templates.firstWhere(
      (t) => t['name'] == templateName,
      orElse: () => null,
    );
    if (template == null) return;

    final items = (template['items'] as List).map((item) {
      return ChecklistItemModel(
        id: IdGenerator.generate(),
        label: item['label'],
        category: ChecklistCategory.fromString(item['category']),
      );
    }).toList();

    // Merge: add items not already in checklist
    final existingLabels = trip.checklist.map((c) => c.label.toLowerCase()).toSet();
    final newItems = items.where(
      (item) => !existingLabels.contains(item.label.toLowerCase()),
    ).toList();
    final updatedTrip = trip.copyWith(
      checklist: [...trip.checklist, ...newItems],
    );
    await notifier.updateTrip(updatedTrip);
  }

  Future<List<String>> getTemplateNames() async {
    final jsonStr = await rootBundle.loadString(AssetPaths.defaultChecklist);
    final data = json.decode(jsonStr);
    final templates = data['templates'] as List;
    return templates.map<String>((t) => t['name'] as String).toList();
  }
}
