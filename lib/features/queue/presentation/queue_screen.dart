import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/queue_providers.dart';
import '../domain/queue_status.dart';

/// Live token screen — `queue.php?action=status`.
///
/// Polls only while open, at the server's `poll_seconds` hint. Tokens are
/// per clinic per day and only exist once reception starts the visit, so a
/// confirmed booking shows "token not issued yet" rather than a number.
class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key, this.appointmentId});

  final int? appointmentId;

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  ApiResult<QueueStatus>? _result;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _timer?.cancel();
    final r = await ref
        .read(queueRepositoryProvider)
        .status(appointmentId: widget.appointmentId);
    if (!mounted) return;
    setState(() => _result = r);

    // Keep polling only while there is a live queue to watch.
    if (r case ApiSuccess(:final value) when value.inQueue) {
      final seconds = (value.queue?.pollSeconds ?? 30).clamp(10, 120);
      _timer = Timer(Duration(seconds: seconds), _load);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final live = r is ApiSuccess<QueueStatus> && r.value.inQueue;
    return AppSubPage(
      title: 'Live queue',
      onRefresh: _load,
      actions: [if (live) const _LiveBadge()],
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
        ApiSuccess(:final value) => _content(context, value),
      },
    );
  }

  List<Widget> _content(BuildContext context, QueueStatus s) {
    if (s.hasNoAppointment || s.appointment == null) {
      return [
        AppPlaceholder(
          icon: AppGlyph.clock,
          title: 'No upcoming appointment',
          message: 'Once a clinic confirms your visit, you can follow the '
              'token queue here on the day.',
          action: FilledButton(
            onPressed: () => context.go('/doctors'),
            child: const Text('Find a doctor'),
          ),
        ),
      ];
    }

    final appt = s.appointment!;
    final q = s.queue;
    return [
      if (s.inQueue && q != null)
        _QueueHero(queue: q)
      else
        AppNote(
          s.isNotToday
              ? 'Your visit is not today. The live queue opens on the day of '
                  'your appointment.'
              : 'The queue is not live for this visit yet.',
          tone: AppTone.brand,
        ),
      const SizedBox(height: 16),
      _ClinicCard(appointment: appt),
      if (s.inQueue && q != null && !q.hasToken) ...[
        const SizedBox(height: 14),
        const AppNote(
          'Your token is issued when reception checks you in. It will appear '
          'here automatically.',
        ),
      ],
      if (q?.checkedAt != null) ...[
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Updated ${_clock(q!.checkedAt!)} · refreshes every '
            '${q.pollSeconds}s',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ];
  }

  static String _clock(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    return d == null ? iso : formatTime(d);
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: t.brandSoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: t.brand, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: TextStyle(
              fontFamily: kFontBody,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: t.brand,
            ),
          ),
        ],
      ),
    );
  }
}

/// The dark "NOW SERVING" hero from the prototype.
class _QueueHero extends StatelessWidget {
  const _QueueHero({required this.queue});

  final QueueInfo queue;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    const onBrand = AppColorsLight.onBrand;
    final mine = queue.myToken;
    final serving = queue.nowServing;
    // Progress through the queue, when both ends are known.
    final pct = (mine != null && serving != null && mine > 0)
        ? (serving / mine).clamp(0.0, 1.0)
        : null;

    TextStyle big(double size) => TextStyle(
          fontFamily: kFontHeading,
          fontSize: size,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: onBrand,
        );
    final small = TextStyle(
      fontFamily: kFontBody,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: onBrand.withValues(alpha: 0.7),
    );

    Widget stat(String value, String label) => Column(
          children: [Text(value, style: big(20)), Text(label, style: small)],
        );
    final divider = Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: 0.15),
    );

    return Container(
      decoration: t.heroDecoration(),
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Text(
            'NOW SERVING',
            style: small.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.14 * 10.5,
            ),
          ),
          Text(serving?.toString() ?? '—', style: big(52)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              stat(queue.hasToken && mine != null ? '$mine' : '—', 'Your token'),
              divider,
              stat(queue.ahead?.toString() ?? '—', 'Ahead of you'),
              divider,
              stat(queue.waiting?.toString() ?? '—', 'Waiting'),
            ],
          ),
          if (pct != null) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ],
          if (queue.ahead != null) ...[
            const SizedBox(height: 8),
            Text(
              queue.ahead == 0
                  ? "You're next — please be at the clinic."
                  : 'Estimate only; the clinic may call tokens out of order.',
              style: small,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _ClinicCard extends StatelessWidget {
  const _ClinicCard({required this.appointment});

  final QueueAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final a = appointment;
    final when = a.when;
    return Container(
      decoration: t.cardDecoration,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AppIcon(AppGlyph.calendar, color: t.ink, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.doctorName ?? a.clinicName ?? 'Your visit',
                    style: text.labelLarge),
                if (a.clinicName != null && a.doctorName != null)
                  Text(a.clinicName!, style: text.bodySmall),
                if (when != null)
                  Text(
                    '${formatDate(toIsoDate(when))} · ${formatTime(when)}',
                    style: text.bodySmall,
                  ),
              ],
            ),
          ),
          if (a.clinicPhone != null)
            GestureDetector(
              onTap: () => launchUrl(Uri(scheme: 'tel', path: a.clinicPhone)),
              child: Text(
                'Call',
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
    );
  }
}
