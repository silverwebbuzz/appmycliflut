import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';

/// Appointments list.
///
/// No longer a tab — reached from Home and from the booking confirmation —
/// so it carries its own back-navigable header. The list itself is wired to
/// the appointments endpoint in a later step; the empty state is real.
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: AppIcon(AppGlyph.chevronLeft, color: t.ink, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text('My visits'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          AppPlaceholder(
            icon: AppGlyph.calendar,
            title: 'No visits yet',
            message: kSkipWhatsAppOtp
                ? 'Test mode is on, so booking needs WhatsApp login. You can '
                    'still browse doctors and clinics.'
                : 'Book an appointment and it will show up here with your '
                    'token and clinic details.',
            action: FilledButton(
              onPressed: () => context.go('/doctors'),
              child: const Text('Find a doctor'),
            ),
          ),
        ],
      ),
    );
  }
}
