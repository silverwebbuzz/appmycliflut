import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/appointments_repository.dart';
import '../domain/appointment.dart';

enum _VisitsTab {
  upcoming('Upcoming'),
  requests('Requests'),
  past('Past');

  const _VisitsTab(this.label);
  final String label;
}

/// My visits — `appointments.php?action=list`.
///
/// Not a tab: reached from Home and from the booking confirmation, so it
/// carries its own back header.
class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  _VisitsTab _tab = _VisitsTab.upcoming;
  ApiResult<AppointmentList>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(appointmentsRepositoryProvider).list();
    if (!mounted) return;
    setState(() {
      _result = r;
      // Land on Requests when that is the only thing there is to see.
      if (r case ApiSuccess(:final value)
          when value.upcoming.isEmpty && value.pending.isNotEmpty) {
        _tab = _VisitsTab.requests;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return AppSubPage(
      title: 'My visits',
      onRefresh: _load,
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
        ApiSuccess(:final value) => [
            AppSegmented<_VisitsTab>(
              values: _VisitsTab.values,
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
              labelOf: (v) => switch (v) {
                _VisitsTab.upcoming => 'Upcoming · ${value.upcoming.length}',
                _VisitsTab.requests => 'Requests · ${value.pending.length}',
                _VisitsTab.past => 'Past',
              },
            ),
            const SizedBox(height: 14),
            ..._list(context, value),
          ],
      },
    );
  }

  List<Widget> _list(BuildContext context, AppointmentList value) {
    final items = switch (_tab) {
      _VisitsTab.upcoming => value.upcoming,
      _VisitsTab.requests => value.pending,
      _VisitsTab.past => value.past,
    };
    if (items.isEmpty) {
      return [
        AppPlaceholder(
          icon: AppGlyph.calendar,
          title: switch (_tab) {
            _VisitsTab.upcoming => 'No upcoming visits',
            _VisitsTab.requests => 'No pending requests',
            _VisitsTab.past => 'No past visits yet',
          },
          message: _tab == _VisitsTab.requests
              ? 'When you request an appointment, it waits here until the '
                  'clinic confirms it.'
              : 'Book an appointment and it will show up here with your '
                  'token and clinic details.',
          action: FilledButton(
            onPressed: () => context.go('/doctors'),
            child: const Text('Find a doctor'),
          ),
        ),
      ];
    }
    return [
      for (final a in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppointmentCard(
            appointment: a,
            showQueue: _tab == _VisitsTab.upcoming,
          ),
        ),
    ];
  }
}

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    this.showQueue = false,
  });

  final Appointment appointment;
  final bool showQueue;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final a = appointment;
    final tone = switch (a.status) {
      'delivery_failed' || 'cancelled' || 'no_show' => AppTone.err,
      'awaiting_clinic' || 'clinic_viewed' => AppTone.warn,
      'completed' => AppTone.muted,
      _ => AppTone.brand,
    };

    return Container(
      decoration: t.cardDecoration,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppInitialsTile(text: a.initials, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: text.labelLarge),
                    if (a.subtitle != null)
                      Text(a.subtitle!, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppStatusPill(a.statusLabel, tone: tone),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AppIcon(AppGlyph.calendar, color: t.sub, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  a.whenLabel.isEmpty ? 'Time to be confirmed' : a.whenLabel,
                  style: text.bodyMedium,
                ),
              ),
              if (a.tokenNumber != null)
                Text(
                  'Token ${a.tokenNumber}',
                  style: text.titleSmall,
                ),
            ],
          ),
          if (a.clinicAddress != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                AppIcon(AppGlyph.pin, color: t.sub, size: 15),
                const SizedBox(width: 6),
                Expanded(child: Text(a.clinicAddress!, style: text.bodySmall)),
              ],
            ),
          ],
          if (a.reason != null) ...[
            const SizedBox(height: 6),
            Text('Reason: ${a.reason}', style: text.bodySmall),
          ],
          if (showQueue || a.clinicPhone != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (showQueue && !a.isLead)
                  Expanded(
                    child: AppSoftButton(
                      label: 'Track token',
                      onTap: () => context.push('/queue?appointment_id=${a.id}'),
                    ),
                  ),
                if (showQueue && !a.isLead && a.clinicPhone != null)
                  const SizedBox(width: 8),
                if (a.clinicPhone != null)
                  Expanded(
                    child: AppSoftButton(
                      label: 'Call clinic',
                      tone: AppTone.muted,
                      onTap: () => launchUrl(Uri(scheme: 'tel', path: a.clinicPhone)),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
