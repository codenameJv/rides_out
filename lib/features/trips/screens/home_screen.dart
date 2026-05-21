import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/animated_fab.dart';
import '../../../shared/widgets/section_header.dart';
import '../providers/trips_provider.dart';
import '../providers/trip_filter_provider.dart';
import '../widgets/trip_card.dart';
import '../widgets/empty_trips_widget.dart';
import '../widgets/search_filter_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);
    final upcoming = ref.watch(upcomingTripsProvider);
    final recent = ref.watch(recentTripsProvider);
    final searchVisible = ref.watch(searchVisibleProvider);
    final filter = ref.watch(tripFilterProvider);
    final filtered = ref.watch(filteredTripsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: Icon(searchVisible ? Icons.search_off : Icons.search),
            tooltip: 'Search',
            onPressed: () {
              final isVisible = ref.read(searchVisibleProvider);
              ref.read(searchVisibleProvider.notifier).state = !isVisible;
              if (isVisible) {
                ref.read(tripFilterProvider.notifier).clearAll();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Statistics',
            onPressed: () => context.push('/stats'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: trips.isEmpty
          ? const EmptyTripsWidget()
          : Column(
              children: [
                if (searchVisible) const SearchFilterBar(),
                Expanded(
                  child: (searchVisible && filter.isActive)
                      ? _FilteredList(filtered: filtered)
                      : ListView(
                          padding: const EdgeInsets.only(
                              bottom: AppDimensions.paddingXL * 2),
                          children: [
                            if (upcoming.isNotEmpty) ...[
                              const SectionHeader(title: 'Upcoming Rides'),
                              ...upcoming.asMap().entries.map(
                                    (e) =>
                                        TripCard(trip: e.value, index: e.key),
                                  ),
                            ],
                            if (recent.isNotEmpty) ...[
                              const SizedBox(height: AppDimensions.paddingSM),
                              const SectionHeader(title: 'All Rides'),
                              ...recent.asMap().entries.map(
                                    (e) => TripCard(
                                      trip: e.value,
                                      index: e.key + upcoming.length,
                                    ),
                                  ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: AnimatedFab(
        onPressed: () => context.push('/trip/new'),
        tooltip: 'Plan a Ride',
      ),
    );
  }
}

class _FilteredList extends StatelessWidget {
  final List filtered;

  const _FilteredList({required this.filtered});

  @override
  Widget build(BuildContext context) {
    if (filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingXL),
          child: Text('No trips match your filters'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingXL * 2),
      children: [
        const SectionHeader(title: 'Results'),
        ...filtered.asMap().entries.map(
              (e) => TripCard(trip: e.value, index: e.key),
            ),
      ],
    );
  }
}
