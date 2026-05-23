import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/overpass_service.dart';
import '../../../core/theme/app_colors.dart';

class PoiMarkerWidget extends StatelessWidget {
  final PoiModel poi;
  final VoidCallback? onTap;

  const PoiMarkerWidget({
    super.key,
    required this.poi,
    this.onTap,
  });

  static Marker toMarker(PoiModel poi, {VoidCallback? onTap}) {
    return Marker(
      point: LatLng(poi.lat, poi.lon),
      width: 30,
      height: 30,
      child: PoiMarkerWidget(poi: poi, onTap: onTap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = OverpassService.categoryIcons[poi.category] ?? '\uD83D\uDCCD';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.5),
          ),
        ),
        child: Center(
          child: Text(
            icon,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
