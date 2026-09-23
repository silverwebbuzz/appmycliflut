import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../doctors/data/doctors_providers.dart';
import '../../doctors/domain/doctor.dart';
import '../../doctors/presentation/widgets/doctor_card.dart';

/// Home tab, rebuilt against the design prototype.
///
/// Layout follows the prototype's home: a greeting header, the dark
/// "next appointment" hero, a 2x2 quick-action grid, then featured doctors.
/// The hero is currently a prompt to book — appointments.php wiring lands
/// with the rest of the API work, at which point it renders the real next
/// visit and queue token.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loading = true;
  String? _error;
  List<Doctor> _featured = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(doctorsRepositoryProvider).search(
          city: 'Ahmedabad',
          perPage: 5,
        );

    if (!mounted) return;
    switch (result) {
      case ApiSuccess(:final value):
        setState(() {
          _featured = value.items;
          _loading = false;
        });
      case ApiFailure(:final message, :final error):
        setState(() {
          _loading = false;
          _error = message ?? error;
        });
    }
  }

  static String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + 16,
          20,
          110 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _Header(greeting: _greeting),
          const SizedBox(height: 18),

          if (kSkipWhatsAppOtp) ...[
            const _TestModeBanner(),
            const SizedBox(height: 14),
          ],

          const _NextAppointmentCard(),
          const SizedBox(height: 14),

          // 2x2 quick actions, as in the prototype.
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  glyph: AppGlyph.person,
                  label: 'Find a doctor',
                  tint: _QuickTint.brand,
                  onTap: () => context.go('/doctors'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  glyph: AppGlyph.flask,
                  label: 'Book lab test',
                  tint: _QuickTint.amber,
                  onTap: () => context.go('/labs'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  glyph: AppGlyph.prescription,
                  label: 'My records',
                  tint: _QuickTint.brand,
                  onTap: () => context.go('/records'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  glyph: AppGlyph.document,
                  label: 'My visits',
                  tint: _QuickTint.amber,
                  onTap: () => context.push('/appointments'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: Text('Doctors near you', style: text.headlineSmall),
              ),
              GestureDetector(
                onTap: () => context.go('/doctors'),
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'See all',
                  style: TextStyle(
                    fontFamily: kFontBody,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: t.brand,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _InlineError(message: _error!, onRetry: _load)
          else if (_featured.isEmpty)
            Text('No doctors found nearby.', style: text.bodySmall)
          else
            ..._featured.map((d) => DoctorCard(doctor: d)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontFamily: kFontBody,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.sub,
                ),
              ),
              Text('Welcome back', style: text.headlineLarge),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.go('/more'),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.brandSoft,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: AppIcon(AppGlyph.person, color: t.brand, size: 20),
          ),
        ),
      ],
    );
  }
}

/// The prototype's dark hero. Until appointments.php is wired this prompts
/// the user to book rather than inventing a fake upcoming visit.
class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final onBrand = AppColorsLight.onBrand;

    return Container(
      decoration: t.heroDecoration(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR NEXT VISIT',
            style: TextStyle(
              fontFamily: kFontBody,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.12 * 10.5,
              color: onBrand.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No upcoming appointments',
            style: TextStyle(
              fontFamily: kFontHeading,
              fontSize: 19,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: onBrand,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Book a doctor and your token, timing and clinic details will '
            'show up here.',
            style: TextStyle(
              fontFamily: kFontBody,
              fontSize: 12.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: onBrand.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.go('/doctors'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.sm + 1),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Text(
                'Find a doctor',
                style: TextStyle(
                  fontFamily: kFontBody,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColorsLight.brandDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _QuickTint { brand, amber }

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.glyph,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final AppGlyph glyph;
  final String label;
  final _QuickTint tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final (bg, fg) = switch (tint) {
      _QuickTint.brand => (t.brandSoft, t.brand),
      _QuickTint.amber => (t.amberSoft, t.amber),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Ink(
          decoration: t.cardDecoration,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: AppIcon(glyph, color: fg, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: TextStyle(
                    fontFamily: kFontBody,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Test-mode notice, shown while [kSkipWhatsAppOtp] bypasses real OTP.
class _TestModeBanner extends StatelessWidget {
  const _TestModeBanner();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: t.amberSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        'Test mode: phone-only login. Booking needs WhatsApp OTP.',
        style: TextStyle(
          fontFamily: kFontBody,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: t.amber,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: t.redSoft,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              fontFamily: kFontBody,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: t.red,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onRetry,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Retry',
              style: TextStyle(
                fontFamily: kFontBody,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: t.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
