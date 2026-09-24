import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/providers.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_providers.dart';

/// Splash: restore session via GET /auth.php?action=me
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    final storage = ref.read(sessionStorageProvider);
    final onboardingDone = await storage.isOnboardingDone();

    // TEST MODE: local phone-only session (no WhatsApp / no API token).
    if (await storage.hasTestSession()) {
      if (!mounted) return;
      context.go('/home');
      return;
    }

    final token = await storage.readToken();

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      context.go(onboardingDone ? '/login' : '/onboarding');
      return;
    }

    final result = await ref.read(authRepositoryProvider).me();
    if (!mounted) return;

    switch (result) {
      case ApiSuccess(:final value):
        if (!mounted) return;
        if (value != null) {
          context.go('/home');
        } else {
          await storage.clearToken();
          if (!mounted) return;
          context.go(onboardingDone ? '/login' : '/onboarding');
        }
      case ApiFailure(:final isLoginRequired):
        if (isLoginRequired) {
          await storage.clearToken();
        }
        if (!mounted) return;
        context.go(onboardingDone ? '/login' : '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandDeep,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Image.asset(
                AppAssets.logoOnDark,
                height: 64,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  AppAssets.logoMark,
                  height: 88,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your clinic, in your pocket',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColorsLight.onBrand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
