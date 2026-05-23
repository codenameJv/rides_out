import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/offline_map_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/confirm_dialog.dart';

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  List<OfflineRegion> _regions = [];
  Future<int>? _storageFuture;

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _storageFuture = OfflineMapService.getTotalStorageSize();
  }

  void _loadRegions() {
    final box = HiveService.settingsBox;
    final regionsJson =
        box.get('offline_regions', defaultValue: '[]') as String;
    try {
      final list = json.decode(regionsJson) as List<dynamic>;
      _regions =
          list.map((j) => OfflineRegion.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      _regions = [];
    }
  }

  void _saveRegions() {
    final regionsJson =
        json.encode(_regions.map((r) => r.toJson()).toList());
    HiveService.settingsBox.put('offline_regions', regionsJson);
  }

  Future<void> _deleteRegion(OfflineRegion region) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Region',
      message:
          'Delete "${region.name}" and its downloaded tiles?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;

    await OfflineMapService.deleteRegion(region);
    setState(() {
      _regions.removeWhere((r) => r.id == region.id);
      _saveRegions();
      _storageFuture = OfflineMapService.getTotalStorageSize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Offline Maps')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final result = await context.push('/offline-maps/download');
          if (result is OfflineRegion && mounted) {
            setState(() {
              _regions.add(result);
              _saveRegions();
              _storageFuture = OfflineMapService.getTotalStorageSize();
            });
          }
        },
        child: const Icon(Icons.download, color: Colors.white),
      ),
      body: Column(
        children: [
          // Storage info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            color: AppColors.surface,
            child: Row(
              children: [
                const Icon(Icons.sd_storage, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text('Total storage: '),
                FutureBuilder<int>(
                  future: _storageFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return Text(
                      OfflineMapService.formatSize(snapshot.data ?? 0),
                      style: AppTextStyles.titleMedium,
                    );
                  },
                ),
              ],
            ),
          ),
          // Regions list
          Expanded(
            child: _regions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_download,
                            size: 48, color: AppColors.textHint),
                        SizedBox(height: 16),
                        Text('No downloaded regions',
                            style: TextStyle(color: AppColors.textHint)),
                        SizedBox(height: 8),
                        Text('Tap + to download a map region',
                            style: TextStyle(
                                color: AppColors.textHint, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppDimensions.paddingMD),
                    itemCount: _regions.length,
                    separatorBuilder: (_, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final region = _regions[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.map,
                              color: AppColors.primary),
                          title: Text(region.name),
                          subtitle: Text(
                            '${region.tileCount} tiles · '
                            '${OfflineMapService.formatSize(region.sizeBytes)} · '
                            'Zoom ${region.minZoom}-${region.maxZoom}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.error),
                            onPressed: () => _deleteRegion(region),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
