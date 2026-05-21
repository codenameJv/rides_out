import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(AppConstants.splashDuration, () {
      if (mounted) context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.two_wheeler,
              size: 80,
              color: AppColors.primary,
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .slideX(begin: -0.3, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.primary,
                fontSize: 36,
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0),
            const SizedBox(height: 8),
            Text(
              AppConstants.appTagline,
              style: AppTextStyles.bodyMedium,
            )
                .animate()
                .fadeIn(delay: 600.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
