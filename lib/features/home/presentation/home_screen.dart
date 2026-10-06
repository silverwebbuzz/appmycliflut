import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../appointments/data/appointments_repository.dart';
import '../../appointments/domain/appointment.dart';
import '../../shop/data/store_repository.dart';
import '../../shop/domain/store_models.dart';
import '../../shop/presentation/shop_widgets.dart';

/// Home tab, rebuilt against the design prototype.
///
/// Layout follows the prototype's home: a greeting header, the dark
/// "next appointment" hero, a 2x2 quick-action grid, then featured doctors.
/// The hero renders `home.php`'s `next_appointment`; with none (or signed
/// out) it prompts the user to book instead of inventing a visit.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loading = true;
  String? _error;
  StoreHome? _store;
  HomeSummary? _summary;

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

    final homeFuture = ref.read(appointmentsRepositoryProvider).home();
    final result = await ref.read(storeRepositoryProvider).home();
    final home = await homeFuture;

    if (!mounted) return;
    // Signed out (or test mode) is normal here: the hero just prompts.
    _summary = home is ApiSuccess<HomeSummary> ? home.value : null;
    switch (result) {
      case ApiSuccess(:final value):
        setState(() {
          _store = value;
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
          _Header(greeting: _greeting, firstName: _summary?.firstName),
          const SizedBox(height: 18),

          if (kSkipWhatsAppOtp) ...[
            const _TestModeBanner(),
            const SizedBox(height: 14),
          ],

          _NextAppointmentCard(summary: _summary),
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
                // Labs is not offered yet (kLabsEnabled). My orders takes
                // its slot: My visits is already on the hero card above.
                child: kLabsEnabled
                    ? _QuickAction(
                        glyph: AppGlyph.flask,
                        label: 'Book lab test',
                        tint: _QuickTint.amber,
                        onTap: () => context.go('/labs'),
                      )
                    : _QuickAction(
                        glyph: AppGlyph.truck,
                        label: 'My orders',
                        tint: _QuickTint.amber,
                        onTap: () => context.push('/shop/orders'),
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
                  glyph: AppGlyph.cart,
                  label: 'Wellness shop',
                  tint: _QuickTint.amber,
                  onTap: () => context.go('/shop'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Product promotion leads Home; doctors live under their own tab.
          Row(
            children: [
              Expanded(
                child: Text('Featured products', style: text.headlineSmall),
              ),
              GestureDetector(
                onTap: () => context.go('/shop'),
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Shop all',
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
          else if (_store == null || _store!.featured.isEmpty && _store!.newArrivals.isEmpty)
            Text('New products are on their way.', style: text.bodySmall)
          else ...[
            if (_store!.featured.isNotEmpty)
              ProductGrid(products: _store!.featured.take(6).toList()),
            if (_store!.newArrivals.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('New arrivals', style: text.headlineSmall),
              const SizedBox(height: 12),
              ProductStrip(products: _store!.newArrivals),
            ],
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting, this.firstName});

  final String greeting;
  final String? firstName;

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
              Text(
                firstName == null ? 'Welcome back' : 'Hi, $firstName',
                style: text.headlineLarge,
              ),
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

/// The prototype's dark hero: the real next visit from `home.php`, or a
/// prompt to book when there is none.
class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({this.summary});

  final HomeSummary? summary;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    const onBrand = AppColorsLight.onBrand;
    final next = summary?.nextAppointment;
    final pending = summary?.pendingRequests ?? 0;

    final eyebrow = TextStyle(
      fontFamily: kFontBody,
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.12 * 10.5,
      color: onBrand.withValues(alpha: 0.7),
    );
    final title = TextStyle(
      fontFamily: kFontHeading,
      fontSize: 19,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: onBrand,
    );
    final body = TextStyle(
      fontFamily: kFontBody,
      fontSize: 12.5,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: onBrand.withValues(alpha: 0.75),
    );

    return Container(
      decoration: t.heroDecoration(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR NEXT VISIT', style: eyebrow),
          const SizedBox(height: 8),
          if (next == null) ...[
            Text('No upcoming appointments', style: title),
            const SizedBox(height: 6),
            Text(
              pending > 0
                  ? 'You have $pending request${pending == 1 ? '' : 's'} '
                      'waiting for a clinic to confirm.'
                  : 'Book a doctor and your token, timing and clinic details '
                      'will show up here.',
              style: body,
            ),
          ] else
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Text(
                    next.initials,
                    style: title.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(next.title, style: title.copyWith(fontSize: 16)),
                      Text(next.whenLabel, style: body),
                      if (next.clinicName != null && next.clinicName != next.title)
                        Text(next.clinicName!, style: body),
                    ],
                  ),
                ),
                if (next.tokenNumber != null)
                  Column(
                    children: [
                      Text('TOKEN', style: eyebrow.copyWith(fontSize: 10)),
                      Text(
                        '${next.tokenNumber}',
                        style: title.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroButton(
                  label: next == null ? 'Find a doctor' : 'Track my token',
                  primary: true,
                  onTap: () => next == null
                      ? context.go('/doctors')
                      : context.push('/queue?appointment_id=${next.id}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroButton(
                  label: 'My visits',
                  onTap: () => context.push('/appointments'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: primary ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.sm + 1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: kFontBody,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: primary ? AppColorsLight.brandDeep : AppColorsLight.onBrand,
          ),
        ),
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
        'Test mode: phone-only login, so there is no server session. The '
        'shop and doctor search work; visits, records, profile, orders and '
        'checkout need a real WhatsApp OTP sign-in.',
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
