import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/points_providers.dart';
import '../data/store_repository.dart';
import '../domain/store_models.dart';

/// My orders — `store_orders.php?action=list`. Labels and tones are the
/// server's (`status_label`, `status_tone`); the app keeps no status table.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  ApiResult<List<OrderListItem>>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(storeRepositoryProvider).orders();
    if (!mounted) return;
    setState(() => _result = r);
    ref.invalidate(pointsSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return AppSubPage(
      title: 'My orders',
      fallbackRoute: '/shop',
      onRefresh: _load,
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [
            AppFailureView(
              failure: r,
              onRetry: _load,
              signInMessage: 'Sign in to see your orders.',
            ),
          ],
        ApiSuccess(:final value) when value.isEmpty => [
            AppPlaceholder(
              icon: AppGlyph.truck,
              title: 'No orders yet',
              message: 'Orders you place in the shop will appear here with '
                  'tracking and invoices.',
              action: FilledButton(
                onPressed: () => context.go('/shop'),
                child: const Text('Browse the shop'),
              ),
            ),
          ],
        ApiSuccess(:final value) => [
            for (final o in value)
              _OrderCard(
                order: o,
                onTap: () async {
                  await context.push('/shop/orders/${o.orderNo}');
                  _load();
                },
              ),
          ],
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final OrderListItem order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final o = order;
    final names = [
      for (final (name, _, qty) in o.preview) qty > 1 ? '$qty × $name' : name,
      if (o.moreItems > 0) '+${o.moreItems} more',
    ].join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Ink(
            decoration: t.cardDecoration,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.orderNo, style: text.labelLarge),
                          Text(
                            '${o.itemCount} item${o.itemCount == 1 ? '' : 's'} · '
                            '${formatPaise(o.grandTotalPaise)}'
                            '${o.placedAt == null ? '' : ' · ${formatDate(o.placedAt)}'}',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    AppStatusPill(o.statusLabel, tone: toneFrom(o.statusTone)),
                  ],
                ),
                if (o.preview.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final (_, img, _) in o.preview.take(3))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: AppNetImage(img, width: 38, height: 38, fit: BoxFit.contain),
                        ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          names,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
                if (o.canPay) ...[
                  const SizedBox(height: 10),
                  AppNote(
                    o.expiresAt == null
                        ? 'Awaiting payment'
                        : 'Awaiting payment · pay by ${formatDateTime(o.expiresAt)}',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
