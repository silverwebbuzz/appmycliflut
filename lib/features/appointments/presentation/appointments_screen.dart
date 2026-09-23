import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_states.dart';

/// Appointments list — full API wiring next; placeholder works in test mode.
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Appointments')),
      body: kSkipWhatsAppOtp
          ? AppEmptyState(
              title: 'No appointments yet',
              subtitle:
                  'In test mode, booking needs WhatsApp login. You can still browse doctors.',
              icon: Icons.calendar_month_outlined,
              actionLabel: 'Find doctors',
              onAction: () => context.go('/doctors'),
            )
          : AppEmptyState(
              title: 'No upcoming visits',
              subtitle: 'Request an appointment with a doctor to see it here.',
              icon: Icons.calendar_month_outlined,
              actionLabel: 'Find doctors',
              onAction: () => context.go('/doctors'),
            ),
    );
  }
}
