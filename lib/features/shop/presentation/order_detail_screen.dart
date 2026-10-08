import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/files/file_actions.dart';
import '../../../core/format/format.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/payment_flow.dart';
import '../data/points_providers.dart';
import '../data/store_repository.dart';
import '../domain/store_models.dart';

/// Order detail — `store_orders.php?action=detail`.
///
/// The UI is driven purely by the server's flags: `can_pay`, `can_cancel`,
/// per-package `can_cancel_items` / `can_return`, per-item `can_review`.
///
/// [payResult] is how checkout hands over: `pending` (or a `paid` the
/// server has not caught up with) re-fetches every 3 s a few times, since
/// the Razorpay webhook may complete the order a moment later.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderNo, this.payResult});

  final String orderNo;
  final String? payResult;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  ApiResult<OrderDetail>? _result;
  bool _busy = false;
  int _confirmPolls = 0;
  Timer? _poll;
  Timer? _tick;

  bool get _confirming => _confirmPolls > 0;

  @override
  void initState() {
    super.initState();
    if (widget.payResult == 'pending' || widget.payResult == 'paid') {
      _confirmPolls = 5;
    }
    _load();
    // Drives the "pay within" countdown.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final r = _result;
      if (mounted && r is ApiSuccess<OrderDetail> && r.value.canPay) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  StoreRepository get _repo => ref.read(storeRepositoryProvider);

  Future<void> _load() async {
    _poll?.cancel();
    final r = await _repo.order(widget.orderNo);
    if (!mounted) return;
    setState(() => _result = r);
    // Payment, cancellation and returns all move points; every reload here
    // follows one of them (or a pull-to-refresh).
    ref.invalidate(pointsSummaryProvider);

    if (_confirming) {
      final stillUnpaid = r is ApiSuccess<OrderDetail> && r.value.canPay;
      if (stillUnpaid) {
        _confirmPolls--;
        _poll = Timer(const Duration(seconds: 3), _load);
      } else {
        setState(() => _confirmPolls = 0);
      }
    }
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    final outcome = await payForOrder(_repo, widget.orderNo);
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome.message != null) showAppSnack(context, outcome.message!);
    if (outcome.result == PayResult.paid || outcome.result == PayResult.pending) {
      setState(() => _confirmPolls = 5);
    }
    _load();
  }

  Future<void> _cancelOrder() async {
    final ok = await confirmAction(
      context,
      title: 'Cancel this order?',
      message: 'Nothing has been charged. The reserved items will be released.',
      confirmLabel: 'Cancel order',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await _repo.cancelOrder(widget.orderNo);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r is ApiSuccess<OrderDetail>) _result = r;
    });
    if (r is ApiFailure<OrderDetail>) showAppSnack(context, friendlyMessage(r));
  }

  Future<void> _cancelItems(OrderDetail o, OrderPackage p) async {
    final done = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CancelItemsSheet(order: o, package: p),
    );
    if (done != null && mounted) {
      showAppSnack(context, done);
      _load();
    }
  }

  Future<void> _return(OrderDetail o, OrderPackage p) async {
    final done = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReturnSheet(order: o, package: p),
    );
    if (done != null && mounted) {
      showAppSnack(context, done);
      _load();
    }
  }

  Future<void> _review(OrderItem item) async {
    final done = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReviewSheet(item: item),
    );
    if (done != null && mounted) {
      showAppSnack(context, done);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final o = r is ApiSuccess<OrderDetail> ? r.value : null;
    return AppSubPage(
      title: 'Order ${widget.orderNo}',
      fallbackRoute: '/shop/orders',
      onRefresh: _load,
      bottomBar: o != null && o.canPay
          ? Row(
              children: [
                if (o.canCancel) ...[
                  SizedBox(
                    width: 110,
                    // Same height as the filled Pay button beside it.
                    height: 52,
                    child: AppSoftButton(
                      label: 'Cancel',
                      tone: AppTone.err,
                      onTap: _busy ? null : _cancelOrder,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Pay ${formatPaise(o.grandTotalPaise)}',
                    busy: _busy,
                    onPressed: _pay,
                  ),
                ),
              ],
            )
          : null,
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
        ApiSuccess(:final value) => _content(context, value),
      },
    );
  }

  List<Widget> _content(BuildContext context, OrderDetail o) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final expires = parseServerDate(o.expiresAt);
    final left = expires?.difference(DateTime.now());

    return [
      Row(
        children: [
          Expanded(
            child: Text(
              o.placedAt == null ? '' : 'Placed ${formatDateTime(o.placedAt)}',
              style: text.bodySmall,
            ),
          ),
          AppStatusPill(o.statusLabel, tone: toneFrom(o.statusTone)),
        ],
      ),
      const SizedBox(height: 10),
      if (_confirming) ...[
        const AppNote('Confirming your payment…', tone: AppTone.brand),
        const SizedBox(height: 8),
      ],
      if (o.noticeText != null) ...[
        AppNote(o.noticeText!, tone: toneFrom(o.noticeTone)),
        const SizedBox(height: 8),
      ],
      if (o.canPay && left != null)
        AppNote(
          left.isNegative
              ? 'The payment window has closed.'
              : 'Pay within ${_mmss(left)} — items are reserved until then.',
        ),

      for (final p in o.packages) ...[
        AppSectionLabel(
          o.packages.length > 1
              ? 'Package ${p.subOrderNo ?? ''} · ${p.sellerName ?? ''}'
              : 'Sold by ${p.sellerName ?? 'seller'}',
          trailing: p.statusLabel == null
              ? null
              : Text(p.statusLabel!, style: text.bodySmall),
        ),
        Container(
          decoration: t.cardDecoration,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (final (i, it) in p.items.indexed)
                _ItemRow(
                  item: it,
                  last: i == p.items.length - 1,
                  onReview: it.canReview ? () => _review(it) : null,
                ),
            ],
          ),
        ),
        if (p.tracking != null) ...[
          const SizedBox(height: 8),
          _TrackingCard(tracking: p.tracking!),
        ],
        for (final ret in p.returns) ...[
          const SizedBox(height: 8),
          AppNote(
            'Return ${ret.returnNo}: ${ret.statusLabel ?? 'requested'}'
            '${ret.refundPaise > 0 ? ' · refund ${formatPaise(ret.refundPaise)}' : ''}',
            tone: AppTone.muted,
          ),
        ],
        if (p.canCancelItems || p.canReturn || p.documents.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (p.canCancelItems)
                _ActionChip('Cancel items', () => _cancelItems(o, p)),
              if (p.canReturn)
                _ActionChip(
                  p.returnUntil == null
                      ? 'Return items'
                      : 'Return (until ${formatDate(p.returnUntil)})',
                  () => _return(o, p),
                ),
              for (final d in p.documents)
                _ActionChip(
                  d.docNo == null ? d.type : '${d.type} ${d.docNo}',
                  () => context.push(Uri(
                    path: '/shop/invoice',
                    queryParameters: {'url': d.url, 'title': d.type},
                  ).toString()),
                ),
            ],
          ),
        ],
      ],

      const AppSectionLabel('Payment'),
      Container(
        decoration: t.cardDecoration,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            AppKeyValue('Items', formatPaise(o.itemsPaise)),
            if (o.discountPaise > 0)
              AppKeyValue(
                o.couponCode == null ? 'Discount' : 'Coupon ${o.couponCode}',
                '− ${formatPaise(o.discountPaise)}',
                valueColor: t.brand,
              ),
            if (o.pointsDiscountPaise > 0)
              AppKeyValue(
                o.pointsUsed > 0 ? 'Points (${o.pointsUsed} pts)' : 'Points',
                '− ${formatPaise(o.pointsDiscountPaise)}',
                valueColor: t.brand,
              ),
            AppKeyValue(
              'Delivery',
              o.shippingPaise == 0 ? 'Free' : formatPaise(o.shippingPaise),
            ),
            Divider(color: t.line, height: 16),
            AppKeyValue('Total', formatPaise(o.grandTotalPaise), strong: true),
            if (o.taxIncludedPaise > 0)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Includes ${formatPaise(o.taxIncludedPaise)} GST',
                  style: text.bodySmall,
                ),
              ),
            if (o.paidAt != null)
              AppKeyValue('Paid on', formatDateTime(o.paidAt)),
          ],
        ),
      ),
      for (final (no, amt, processed) in o.refunds) ...[
        const SizedBox(height: 8),
        AppNote(
          'Refund $no: ${formatPaise(amt)} · '
          '${processed ? 'processed to your original payment method' : 'in progress (5–7 working days)'}',
          tone: AppTone.muted,
        ),
      ],
      if (o.shipTo != null) ...[
        const AppSectionLabel('Delivering to'),
        Container(
          width: double.infinity,
          decoration: t.cardDecoration,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.shipTo!.name, style: text.labelLarge),
              Text(o.shipTo!.oneLine, style: text.bodySmall),
              Text(o.shipTo!.phone, style: text.bodySmall),
            ],
          ),
        ),
      ],
    ];
  }

  static String _mmss(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: t.brandSoft,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: kFontBody,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: t.brand,
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.last, this.onReview});

  final OrderItem item;
  final bool last;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final it = item;
    final notes = [
      if (it.qtyCancelled > 0) '${it.qtyCancelled} cancelled',
      if (it.qtyReturned > 0) '${it.qtyReturned} returned',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppNetImage(it.image, width: 48, height: 48, fit: BoxFit.contain),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.name, style: text.labelLarge?.copyWith(fontSize: 12.5)),
                Text(
                  '${it.variantTitle == null ? '' : '${it.variantTitle} · '}'
                  'Qty ${it.qty} · ${formatPaise(it.lineTotalPaise)}',
                  style: text.bodySmall,
                ),
                if (notes.isNotEmpty) Text(notes, style: text.bodySmall),
                if (onReview != null)
                  GestureDetector(
                    onTap: onReview,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(AppGlyph.star, color: t.amber, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Rate this product',
                            style: TextStyle(
                              fontFamily: kFontBody,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: t.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.tracking});

  final Tracking tracking;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final tr = tracking;
    return Container(
      decoration: t.cardDecoration,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(AppGlyph.truck, color: t.ink, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tr.statusLabel ?? 'Shipped', style: text.labelLarge),
              ),
              if (tr.url != null)
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse(tr.url!),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(
                    'Track',
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
          if (tr.courier != null || tr.awb != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [tr.courier, if (tr.awb != null) 'AWB ${tr.awb}']
                    .whereType<String>()
                    .join(' · '),
                style: text.bodySmall,
              ),
            ),
          for (final e in tr.events.take(5))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 5, right: 10),
                    decoration: BoxDecoration(color: t.brand, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(
                      [e.status, e.location].whereType<String>().join(' · '),
                      style: text.bodyMedium,
                    ),
                  ),
                  if (e.at != null) Text(formatDate(e.at), style: text.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action sheets. Each pops the server's message on success.
// ---------------------------------------------------------------------------

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-item quantity pickers, 0…[maxOf].
class _QtyPicker extends StatelessWidget {
  const _QtyPicker({
    required this.items,
    required this.maxOf,
    required this.qty,
    required this.onChanged,
  });

  final List<OrderItem> items;
  final int Function(OrderItem) maxOf;
  final Map<int, int> qty;
  final void Function(int itemId, int qty) onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final it in items.where((i) => maxOf(i) > 0))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Expanded(child: Text(it.name, style: text.bodyMedium)),
                DropdownButton<int>(
                  value: qty[it.id] ?? 0,
                  items: [
                    for (var n = 0; n <= maxOf(it); n++)
                      DropdownMenuItem(value: n, child: Text('$n')),
                  ],
                  onChanged: (v) => onChanged(it.id, v ?? 0),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CancelItemsSheet extends ConsumerStatefulWidget {
  const _CancelItemsSheet({required this.order, required this.package});

  final OrderDetail order;
  final OrderPackage package;

  @override
  ConsumerState<_CancelItemsSheet> createState() => _CancelItemsSheetState();
}

class _CancelItemsSheetState extends ConsumerState<_CancelItemsSheet> {
  final _qty = <int, int>{};
  String? _reason;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final items = {
      for (final e in _qty.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (items.isEmpty || _reason == null) {
      setState(() => _error = 'Pick at least one item and a reason.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(storeRepositoryProvider).cancelItems(
          orderNo: widget.order.orderNo,
          items: items,
          reason: _reason!,
        );
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final value):
        Navigator.of(context).pop(value);
      case ApiFailure():
        setState(() {
          _busy = false;
          _error = friendlyMessage(r);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Cancel items',
      children: [
        _QtyPicker(
          items: widget.package.items,
          maxOf: (i) => i.cancellableQty,
          qty: _qty,
          onChanged: (id, q) => setState(() => _qty[id] = q),
        ),
        const AppSectionLabel('Reason'),
        AppChoiceChips<String>(
          options: widget.order.cancelReasons,
          selected: _reason,
          onSelected: (v) => setState(() => _reason = v),
          labelOf: (v) => v,
        ),
        const SizedBox(height: 12),
        Text(
          'The refund goes to your original payment method in 5–7 working days.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          AppNote(_error!, tone: AppTone.err),
        ],
        const SizedBox(height: 14),
        AppPrimaryButton(label: 'Cancel selected items', busy: _busy, onPressed: _submit),
      ],
    );
  }
}

class _ReturnSheet extends ConsumerStatefulWidget {
  const _ReturnSheet({required this.order, required this.package});

  final OrderDetail order;
  final OrderPackage package;

  @override
  ConsumerState<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<_ReturnSheet> {
  final _qty = <int, int>{};
  final _note = TextEditingController();
  final _photos = <PickedFile>[];
  ReturnReason? _reason;
  bool _busy = false;
  String? _error;

  bool get _photoRequired =>
      _reason != null && widget.order.photoRequiredFor.contains(_reason!.key);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final f = await pickDocumentOrPhoto(context, allowPdf: false);
    if (f != null) setState(() => _photos.add(f));
  }

  Future<void> _submit() async {
    final items = {
      for (final e in _qty.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (items.isEmpty || _reason == null) {
      setState(() => _error = 'Pick at least one item and a reason.');
      return;
    }
    if (_photoRequired && _photos.isEmpty) {
      setState(() => _error = 'Please add a photo for this reason.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(storeRepositoryProvider).requestReturn(
          vendorOrderId: widget.package.id,
          items: items,
          reason: _reason!.key,
          note: _note.text.trim(),
          photoPaths: [for (final p in _photos) p.path],
        );
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final value):
        Navigator.of(context).pop(value);
      case ApiFailure():
        setState(() {
          _busy = false;
          _error = friendlyMessage(r);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return _SheetFrame(
      title: 'Return items',
      children: [
        _QtyPicker(
          items: widget.package.items,
          maxOf: (i) => i.returnableQty,
          qty: _qty,
          onChanged: (id, q) => setState(() => _qty[id] = q),
        ),
        const AppSectionLabel('Reason'),
        AppChoiceChips<ReturnReason>(
          options: widget.order.returnReasons,
          selected: _reason,
          onSelected: (v) => setState(() => _reason = v),
          labelOf: (v) => v.label,
        ),
        AppLabeledField(
          label: 'Note · optional',
          controller: _note,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        AppSectionLabel(_photoRequired ? 'Photos · required' : 'Photos · optional'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, p) in _photos.indexed)
              Chip(
                label: Text(p.name, overflow: TextOverflow.ellipsis),
                onDeleted: () => setState(() => _photos.removeAt(i)),
              ),
            if (_photos.length < 3)
              GestureDetector(
                onTap: _addPhoto,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: t.line),
                  ),
                  child: Text(
                    '+ Add photo',
                    style: TextStyle(
                      fontFamily: kFontBody,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.brand,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          AppNote(_error!, tone: AppTone.err),
        ],
        const SizedBox(height: 14),
        AppPrimaryButton(label: 'Request return', busy: _busy, onPressed: _submit),
      ],
    );
  }
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.item});

  final OrderItem item;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  int _rating = 0;
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Tap the stars to rate.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(storeRepositoryProvider).review(
          orderItemId: widget.item.id,
          rating: _rating,
          title: _title.text.trim(),
          body: _body.text.trim(),
        );
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final value):
        Navigator.of(context).pop(value);
      case ApiFailure():
        setState(() {
          _busy = false;
          _error = friendlyMessage(r);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return _SheetFrame(
      title: 'Rate ${widget.item.name}',
      children: [
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => setState(() => _rating = i),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: AppIcon(
                    AppGlyph.star,
                    color: i <= _rating ? t.amber : t.line,
                    size: 34,
                  ),
                ),
              ),
          ],
        ),
        AppLabeledField(
          label: 'Title · optional',
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
        ),
        AppLabeledField(
          label: 'Your experience · optional',
          controller: _body,
          hint: 'Quality, packaging, how it suited you',
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 6),
        Text(
          'Share your product experience, not medical advice. Reviews are '
          'checked before they appear.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          AppNote(_error!, tone: AppTone.err),
        ],
        const SizedBox(height: 14),
        AppPrimaryButton(label: 'Submit review', busy: _busy, onPressed: _submit),
      ],
    );
  }
}
