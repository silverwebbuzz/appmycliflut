import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/network/api_result.dart';
import '../../../core/widgets/app_ui.dart';
import 'store_repository.dart';

enum PayResult {
  /// Server confirmed with Razorpay.
  paid,

  /// Not confirmed yet: re-fetch the order shortly. The Razorpay webhook
  /// completes the order even if `pay_verify` never arrives.
  pending,

  /// Razorpay says it failed; the order is still payable until it expires.
  failed,

  /// The user closed the sheet. The order stays payable.
  cancelled,

  /// `pay_start` refused, or payments cannot run here.
  error,
}

/// True while the Razorpay sheet is open (from `open()` until it reports
/// back). Other UI, such as the app-update dialog, waits for it.
final ValueNotifier<bool> paymentInProgress = ValueNotifier<bool>(false);

class PayOutcome {
  const PayOutcome(this.result, [this.message]);

  final PayResult result;
  final String? message;
}

/// `pay_start` → Razorpay SDK → `pay_verify` for one order.
///
/// The decision is always the server's (it asks Razorpay's API); the app
/// only relays what the SDK returned. Safe to call again for the same
/// order: `pay_start` reuses the same Razorpay order.
Future<PayOutcome> payForOrder(StoreRepository repo, String orderNo) async {
  // The SDK is a platform plugin for Android and iOS only; calling it
  // elsewhere throws inside an unawaited future that cannot be caught.
  final supported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (!supported) {
    return const PayOutcome(
      PayResult.error,
      'Payments open in the Android or iOS app. Your order is saved and can '
      'be paid from My orders.',
    );
  }

  final start = await repo.payStart(orderNo);
  final Map<String, dynamic> c;
  switch (start) {
    case ApiSuccess(:final value):
      c = value;
    case ApiFailure():
      return PayOutcome(PayResult.error, friendlyMessage(start));
  }

  final done = Completer<PayOutcome>();
  final razorpay = Razorpay();

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) async {
    final v = await repo.payVerify(
      orderNo: orderNo,
      razorpayOrderId: r.orderId,
      paymentId: r.paymentId,
      signature: r.signature,
    );
    if (done.isCompleted) return;
    done.complete(switch (v) {
      ApiSuccess(:final value) => switch (value.state) {
          'paid' => const PayOutcome(PayResult.paid),
          'failed' => const PayOutcome(
              PayResult.failed,
              'Payment failed. You can try again.',
            ),
          _ => const PayOutcome(PayResult.pending),
        },
      // Money may have moved even if our server call failed.
      ApiFailure() => const PayOutcome(
          PayResult.pending,
          'If money was deducted, it will reflect on your order within a few '
          'minutes.',
        ),
    });
  });

  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
    if (done.isCompleted) return;
    done.complete(PayOutcome(
      r.code == Razorpay.PAYMENT_CANCELLED ? PayResult.cancelled : PayResult.failed,
      r.code == Razorpay.PAYMENT_CANCELLED
          ? 'Payment not completed. You can pay any time before the order '
              'expires.'
          : (r.message ?? 'Payment failed. You can try again.'),
    ));
  });

  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
    if (done.isCompleted) return;
    done.complete(const PayOutcome(PayResult.pending));
  });

  paymentInProgress.value = true;
  razorpay.open({
    'key': c['key'],
    'order_id': c['order_id'],
    'amount': c['amount'],
    'currency': c['currency'],
    'name': c['name'],
    'description': c['description'],
    'prefill': c['prefill'],
    'notes': c['notes'],
    'theme': c['theme'],
  });

  final PayOutcome outcome;
  try {
    outcome = await done.future;
  } finally {
    paymentInProgress.value = false;
  }
  razorpay.clear();
  return outcome;
}
