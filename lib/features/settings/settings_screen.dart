import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/services/data_export_service.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/tile_cache_service.dart';
import '../../shared/providers/settings_provider.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../trips/providers/trips_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<int>? _cacheSizeFuture;

  @override
  void initState() {
    super.initState();
    _cacheSizeFuture = TileCacheService.getCacheSize();
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripsProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: AppDimensions.paddingSM),

          // Routing
          _SectionTitle('Routing'),
          SwitchListTile(
            secondary: const Icon(Icons.block, color: AppColors.textSecondary),
            title: const Text('Avoid expressways & tolls'),
            subtitle: const Text(
                'Exclude toll roads and expressways from route planning'),
            value: settings.avoidTollsExpressways,
            activeTrackColor: AppColors.primary,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setAvoidTollsExpressways(value);
            },
          ),
          const Divider(),

          // App info
          _SectionTitle('About'),
          ListTile(
            leading:
                const Icon(Icons.two_wheeler, color: AppColors.primary),
            title: Text(AppConstants.appName,
                style: AppTextStyles.titleMedium),
            subtitle: const Text('v1.0.0'),
          ),
          const Divider(),

          // Data
          _SectionTitle('Data'),
          ListTile(
            leading: const Icon(Icons.storage, color: AppColors.textSecondary),
            title: const Text('Trips stored'),
            trailing: Text('${trips.length}',
                style: AppTextStyles.titleMedium),
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_forever, color: AppColors.error),
            title: const Text('Delete all data'),
            subtitle: const Text('Remove all trips and data'),
            onTap: () async {
              final confirmed = await ConfirmDialog.show(
                context,
                title: 'Delete All Data',
                message:
                    'This will permanently delete all ${trips.length} trips and their data. This cannot be undone.',
                confirmLabel: 'Delete All',
              );
              if (confirmed) {
                await HiveService.tripsBox.clear();
                ref.invalidate(tripsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All data deleted')),
                  );
                }
              }
            },
          ),
          const Divider(),

          // Backup & Transfer
          _SectionTitle('Backup & Transfer'),
          ListTile(
            leading: const Icon(Icons.upload_file,
                color: AppColors.textSecondary),
            title: const Text('Export Data'),
            subtitle: const Text('Share all trips as a backup file'),
            onTap: () async {
              try {
                await DataExportService.exportData(trips);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.download,
                color: AppColors.textSecondary),
            title: const Text('Import Data'),
            subtitle: const Text('Restore trips from a backup file'),
            onTap: () async {
              try {
                final imported = await DataExportService.importData();
                if (imported == null) return;
                if (!context.mounted) return;

                final existingIds =
                    trips.map((t) => t.id).toSet();
                final newTrips = imported
                    .where((t) => !existingIds.contains(t.id))
                    .toList();

                if (newTrips.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('No new trips to import (all already exist)')),
                  );
                  return;
                }

                final confirmed = await ConfirmDialog.show(
                  context,
                  title: 'Import Trips',
                  message:
                      'Add ${newTrips.length} new trip${newTrips.length == 1 ? '' : 's'} to your data? Existing trips will not be modified.',
                  confirmLabel: 'Import',
                );
                if (!confirmed) return;

                for (final trip in newTrips) {
                  await HiveService.tripsBox.put(trip.id, trip);
                }
                ref.invalidate(tripsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${newTrips.length} trip${newTrips.length == 1 ? '' : 's'} imported')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Import failed: $e')),
                  );
                }
              }
            },
          ),
          const Divider(),

          // Map cache
          _SectionTitle('Map Cache'),
          ListTile(
            leading:
                const Icon(Icons.map_outlined, color: AppColors.textSecondary),
            title: const Text('Map tile cache'),
            trailing: FutureBuilder<int>(
              future: _cacheSizeFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                return Text(
                  TileCacheService.formatCacheSize(snapshot.data ?? 0),
                  style: AppTextStyles.titleMedium,
                );
              },
            ),
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_sweep, color: AppColors.error),
            title: const Text('Clear map cache'),
            subtitle: const Text('Remove cached map tiles'),
            onTap: () async {
              await TileCacheService.clearCache();
              setState(() {
                _cacheSizeFuture = TileCacheService.getCacheSize();
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Map cache cleared')),
                );
              }
            },
          ),
          const Divider(),

          // Credits
          _SectionTitle('Credits'),
          const ListTile(
            leading:
                Icon(Icons.map, color: AppColors.textSecondary),
            title: Text('Map tiles by OpenStreetMap'),
            subtitle: Text(AppConstants.osmAttribution),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        AppDimensions.paddingMD,
        AppDimensions.paddingMD,
        AppDimensions.paddingXS,
      ),
      child: Text(
        title,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
