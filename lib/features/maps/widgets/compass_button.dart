import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../core/theme/app_colors.dart';

class CompassButton extends StatelessWidget {
  final MapController mapController;
  final double rotation;

  const CompassButton({
    super.key,
    required this.mapController,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    // Hide when pointing north (within ~2 degrees)
    if (rotation.abs() < 0.035) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => mapController.rotate(0),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.textHint.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: rotation,
          child: CustomPaint(
            size: const Size(24, 24),
            painter: _CompassPainter(),
          ),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // North half (red)
    final northPath = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx - 5, center.dy)
      ..lineTo(center.dx + 5, center.dy)
      ..close();

    canvas.drawPath(
      northPath,
      Paint()..color = AppColors.error,
    );

    // South half (white/light)
    final southPath = Path()
      ..moveTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - 5, center.dy)
      ..lineTo(center.dx + 5, center.dy)
      ..close();

    canvas.drawPath(
      southPath,
      Paint()..color = AppColors.textSecondary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
