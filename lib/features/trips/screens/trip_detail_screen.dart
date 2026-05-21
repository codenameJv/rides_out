import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../local_db/models/enums.dart';
import '../../../local_db/models/trip_model.dart';
import '../providers/trips_provider.dart';
import '../../itinerary/screens/itinerary_screen.dart';
import '../../checklist/screens/checklist_screen.dart';
import '../../expenses/screens/expenses_screen.dart';

class TripDetailScreen extends ConsumerWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripByIdProvider(tripId));

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Trip not found')),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(trip.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.map),
              tooltip: 'Map View',
              onPressed: () => context.push('/trip/${trip.id}/map'),
            ),
            PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit Trip')),
                const PopupMenuItem(
                    value: 'duplicate', child: Text('Duplicate Trip')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Trip',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
              onSelected: (value) async {
                if (value == 'edit') {
                  context.push('/trip/${trip.id}/edit');
                } else if (value == 'duplicate') {
                  final copy = await ref
                      .read(tripsProvider.notifier)
                      .duplicateTrip(trip.id);
                  if (copy != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Trip duplicated')),
                    );
                    context.push('/trip/${copy.id}/edit');
                  }
                } else if (value == 'delete') {
                  final confirmed = await ConfirmDialog.show(
                    context,
                    title: 'Delete Trip',
                    message:
                        'Are you sure you want to delete "${trip.name}"? This cannot be undone.',
                  );
                  if (confirmed && context.mounted) {
                    ref.read(tripsProvider.notifier).deleteTrip(trip.id);
                    context.go('/');
                  }
                }
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Overview'),
              Tab(icon: Icon(Icons.route), text: 'Itinerary'),
              Tab(icon: Icon(Icons.checklist), text: 'Checklist'),
              Tab(icon: Icon(Icons.attach_money), text: 'Expenses'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(tripId: tripId),
            ItineraryScreen(tripId: tripId),
            ChecklistScreen(tripId: tripId),
            ExpensesScreen(tripId: tripId),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  final String tripId;
  const _OverviewTab({required this.tripId});

  void _showBudgetDialog(BuildContext context, WidgetRef ref, TripModel trip) {
    final controller = TextEditingController(
      text: trip.budget > 0 ? trip.budget.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Budget'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: '₱ ',
            hintText: '0',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newBudget = double.tryParse(controller.text) ?? 0;
              final updated = trip.copyWith(budget: newBudget);
              ref.read(tripsProvider.notifier).updateTrip(updated);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripByIdProvider(tripId));
    if (trip == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      children: [
        // Status & dates
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      DateFormatter.dateRange(trip.startDate, trip.endDate),
                      style: AppTextStyles.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      DateFormatter.tripDuration(trip.startDate, trip.endDate),
                      style: AppTextStyles.bodyMedium,
                    ),
                    const Spacer(),
                    Text(
                      DateFormatter.daysUntil(trip.startDate),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (trip.description != null && trip.description!.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.paddingSM),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text(trip.description!, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: AppDimensions.paddingSM),

        // Stats cards
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.route,
                label: 'Stops',
                value: '${trip.stops.length}',
                onTap: () => DefaultTabController.of(context).animateTo(1),
              ),
            ),
            const SizedBox(width: AppDimensions.paddingSM),
            Expanded(
              child: _StatCard(
                icon: Icons.checklist,
                label: 'Packed',
                value: '${trip.checklistProgress}%',
                onTap: () => DefaultTabController.of(context).animateTo(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.paddingSM),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.attach_money,
                label: 'Spent',
                value: CurrencyFormatter.compact(trip.totalExpenses),
                onTap: () => DefaultTabController.of(context).animateTo(3),
              ),
            ),
            const SizedBox(width: AppDimensions.paddingSM),
            Expanded(
              child: _StatCard(
                icon: Icons.account_balance_wallet,
                label: 'Budget',
                value: trip.budget > 0
                    ? CurrencyFormatter.compact(trip.budget)
                    : 'Not set',
                onTap: () => _showBudgetDialog(context, ref, trip),
              ),
            ),
          ],
        ),

        // Start Ride button
        if (trip.status == TripStatus.planning ||
            trip.status == TripStatus.upcoming ||
            trip.status == TripStatus.active) ...[
          const SizedBox(height: AppDimensions.paddingMD),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  context.push('/trip/${trip.id}/ride'),
              icon: Icon(trip.hasRecordedRoute
                  ? Icons.replay
                  : Icons.two_wheeler),
              label: Text(trip.hasRecordedRoute
                  ? 'Ride Again'
                  : 'Start Ride'),
            ),
          ),
          if (trip.hasRecordedRoute)
            Padding(
              padding:
                  const EdgeInsets.only(top: AppDimensions.paddingXS),
              child: Text(
                'This will replace the existing recorded route.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 8),
              Text(value, style: AppTextStyles.headlineSmall),
              const SizedBox(height: 4),
              Text(label, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
