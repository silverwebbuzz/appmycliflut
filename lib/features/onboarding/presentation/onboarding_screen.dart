import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/session_storage.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    (
      title: 'Find doctors near you',
      body: 'Search by specialty, city, or name and request an appointment.',
      image: AppAssets.onboardingFindDoctors,
    ),
    (
      title: 'Book in a few taps',
      body: 'Request a visit and the clinic will confirm with you on WhatsApp.',
      image: AppAssets.onboardingBooking,
    ),
    (
      title: 'Your health, organized',
      body: 'Keep appointments and care details securely in one place.',
      image: AppAssets.onboardingLocker,
    ),
  ];

  Future<void> _finish() async {
    await SessionStorage().setOnboardingDone();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppTokens.of(context).bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Image.asset(AppAssets.logoMark, height: 36),
                  const SizedBox(width: 10),
                  Image.asset(
                    AppAssets.logo,
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: AspectRatio(
                            aspectRatio: 1.15,
                            child: ColoredBox(
                              color: AppTokens.of(context).brandSoft,
                              child: Image.asset(
                                page.image,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: active ? 22 : 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppTokens.of(context).brand
                        : AppTokens.of(context).line,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: FilledButton(
                onPressed: () {
                  if (isLast) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Text(isLast ? 'Get started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
