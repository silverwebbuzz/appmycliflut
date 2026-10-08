import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/points_providers.dart';
import '../domain/points_models.dart';

/// eClinicPro Points & Refer — `store_points.php?action=summary` (doc 12).
///
/// Read-only: the server earns and spends points. Wording rule: always
/// "points" (1 point = ₹1 off); never money, cash, wallet or credit.
class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});

  static final _terms = Uri.parse('https://eclinicpro.com/terms#points');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pointsSummaryProvider);
    Future<void> refresh() => ref.refresh(pointsSummaryProvider.future);

    return AppSubPage(
      title: 'Points & Refer',
      fallbackRoute: '/more',
      onRefresh: refresh,
      children: switch (async) {
        AsyncData(value: ApiSuccess(:final value)) when value.enabled =>
          _content(context, value),
        AsyncData(value: ApiSuccess()) ||
        AsyncData(value: ApiFailure(error: 'store_unavailable')) =>
          const [
            AppPlaceholder(
              icon: AppGlyph.star,
              title: 'Points are not available right now',
              message: 'Please check back soon.',
            ),
          ],
        AsyncData(value: final ApiFailure<PointsSummary> f) => [
            AppFailureView(
              failure: f,
              onRetry: () => ref.invalidate(pointsSummaryProvider),
              signInMessage: 'Sign in to see your points and referral code.',
            ),
          ],
        _ => const [AppLoadingView()],
      },
    );
  }

  List<Widget> _content(BuildContext context, PointsSummary s) {
    final empty = s.balance.available == 0 &&
        s.balance.pending == 0 &&
        s.lots.isEmpty &&
        s.history.isEmpty;
    final rules = rulesText(s.rules);
    return [
      if (empty)
        const AppPlaceholder(
          icon: AppGlyph.star,
          title: 'No points yet',
          message: 'Points you earn on store orders and referrals will show '
              'up here.',
        )
      else
        _BalanceCard(balance: s.balance),
      if (rules.isNotEmpty) ...[
        const SizedBox(height: 12),
        AppNote(rules, tone: AppTone.brand),
      ],
      if (s.lots.isNotEmpty) ...[
        const AppSectionLabel('Your points'),
        for (final lot in s.lots) _LotRow(lot: lot),
      ],
      const AppSectionLabel('Refer & earn'),
      _ReferralCard(summary: s),
      if (s.referral.friends.isNotEmpty) ...[
        const AppSectionLabel('Friends'),
        AppGroup(
          children: [
            for (final (i, f) in s.referral.friends.indexed)
              AppGroupRow(
                label: f.name,
                sub: f.joinedAt == null ? null : 'Joined ${formatDate(f.joinedAt)}',
                last: i == s.referral.friends.length - 1,
                trailing: Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppStatusPill(
                      friendStatusLabel(f.status),
                      tone: switch (f.status) {
                        'rewarded' => AppTone.brand,
                        'rejected' => AppTone.muted,
                        _ => AppTone.warn,
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
      if (s.history.isNotEmpty) _HistorySection(history: s.history),
      const SizedBox(height: 22),
      Text(
        "Points are a discount on eClinicPro Store orders only. They have no "
        "cash value and can't be withdrawn, bought or transferred.",
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => launchUrl(_terms, mode: LaunchMode.externalApplication),
          child: Text(
            'Points terms',
            style: TextStyle(
              fontFamily: kFontBody,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTokens.of(context).brand,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    ];
  }
}

/// The rules line, built only from the server's numbers (admin can change
/// them). A sentence whose numbers are missing is left out.
String rulesText(PointsRules r) {
  final parts = <String>[
    if (r.welcomeMinOrderPaise != null)
      'Welcome points are used together on an order of '
          '${formatPaise(r.welcomeMinOrderPaise!)} or more.',
    if (r.redeemCapPct != null)
      'Referral and loyalty points cover up to ${r.redeemCapPct}% of an order.',
    if (r.loyaltyPct != null && r.returnWindowDays != null)
      'An order that uses no points earns ${r.loyaltyPct}% of its value as '
          'points, ${r.returnWindowDays} days after delivery.',
  ];
  return parts.join(' ');
}

String lotKindLabel(String kind) => switch (kind) {
      'welcome' => 'Welcome',
      'referral' => 'Referral',
      'loyalty' => 'Loyalty',
      'admin' => 'Bonus',
      final k => k.isEmpty ? 'Points' : k[0].toUpperCase() + k.substring(1),
    };

String friendStatusLabel(String status) => switch (status) {
      'signed_up' => 'Waiting for first order',
      'qualified' => 'Delivered · in return window',
      'rewarded' => 'Points given',
      'rejected' => 'Not eligible',
      _ => status,
    };

String historyTypeLabel(String type) => switch (type) {
      'earn' => 'Earned',
      'available' => 'Ready to use',
      'spend' => 'Used on order',
      'refund' => 'Returned',
      'expire' => 'Expired',
      'reverse' => 'Cancelled',
      'adjust' => 'Adjusted',
      _ => type,
    };

/// "Ready to use · Expires 05 Apr 2027" / "Pending · `note` · from 14 Oct 2026".
String lotStatusLine(PointsLot lot) {
  if (lot.isAvailable) {
    return lot.expiresAt == null
        ? 'Ready to use'
        : 'Ready to use · Expires ${formatDate(lot.expiresAt)}';
  }
  return [
    'Pending',
    ?lot.note,
    if (lot.availableAt != null) 'from ${formatDate(lot.availableAt)}',
  ].join(' · ');
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final PointsBalance balance;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    const onBrand = AppColorsLight.onBrand;
    Widget stat(int n, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$n',
                  style: const TextStyle(
                    fontFamily: kFontHeading,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: onBrand,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontFamily: kFontBody,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onBrand.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        );
    return Container(
      decoration: t.heroDecoration(),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          stat(balance.available, 'points ready to use'),
          Container(
            width: 1,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: Colors.white.withValues(alpha: 0.15),
          ),
          stat(balance.pending, 'points pending'),
        ],
      ),
    );
  }
}

class _LotRow extends StatelessWidget {
  const _LotRow({required this.lot});

  final PointsLot lot;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: t.cardDecoration,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppStatusPill(
                  lotKindLabel(lot.kind),
                  tone: lot.isAvailable ? AppTone.brand : AppTone.warn,
                ),
                const SizedBox(height: 6),
                Text(lotStatusLine(lot), style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${lot.points} pts', style: text.titleMedium),
        ],
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.summary});

  final PointsSummary summary;

  Future<void> _share(BuildContext context, String text) async {
    // iPad anchors the share sheet to the button.
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: text,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final r = summary.referral;

    if (!r.active || r.code == null) {
      return Container(
        decoration: t.cardDecoration,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('🔒 Your referral code unlocks after your first store order '
                'is delivered.',
                style: text.bodyMedium),
            const SizedBox(height: 12),
            AppSoftButton(label: 'Shop now', onTap: () => context.go('/shop')),
          ],
        ),
      );
    }

    final share = summary.shareText ?? r.link ?? r.code!;
    return Container(
      decoration: t.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (summary.rules.referralPoints != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Invite friends with your code. You get '
                '${summary.rules.referralPoints} points when their first '
                'order is delivered.',
                style: text.bodyMedium,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: t.chip,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: t.line),
            ),
            child: FittedBox(
              // Long codes shrink to fit a 360dp screen instead of clipping.
              fit: BoxFit.scaleDown,
              child: SelectableText(
                r.code!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: const ['Menlo', 'Courier'],
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: t.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (btnContext) => FilledButton(
                    onPressed: () => _share(btnContext, share),
                    child: const Text('Share'),
                  ),
                ),
              ),
              if (r.link != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: AppSoftButton(
                      label: 'Copy link',
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: r.link!));
                        if (context.mounted) showAppSnack(context, 'Link copied');
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (r.rewarded > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${r.rewarded} friend${r.rewarded == 1 ? '' : 's'} rewarded so far',
              style: text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _HistorySection extends StatefulWidget {
  const _HistorySection({required this.history});

  final List<PointsHistoryEntry> history;

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final items = widget.history.take(30).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              const Expanded(child: AppSectionLabel('Points history')),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _open ? 'Hide' : 'Show',
                  style: TextStyle(
                    fontFamily: kFontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.brand,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_open)
          AppGroup(
            children: [
              for (final (i, h) in items.indexed)
                AppGroupRow(
                  label: historyTypeLabel(h.type),
                  sub: [
                    if (h.kind != null) lotKindLabel(h.kind!),
                    ?h.orderNo,
                    ?h.note,
                    if (h.at != null) formatDate(h.at),
                  ].join(' · '),
                  last: i == items.length - 1,
                  trailing: Text(
                    '${h.points > 0 ? '+' : ''}${h.points} pts',
                    style: text.labelLarge?.copyWith(
                      color: h.points < 0 ? t.sub : t.ink,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
