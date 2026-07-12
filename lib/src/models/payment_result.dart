import '../enums.dart';
import 'sanitized_payment.dart';

/// The terminal outcome of a checkout. NOT an error — a cancelled/expired/failed
/// payment is a normal result; only SDK/credential faults throw a
/// GbitxPayException. `payment` is populated in practice for confirmed checkouts
/// but is nullable because a bridge message is device-controllable and UX-only:
/// fulfilment is driven by the signed server webhook.
sealed class PaymentResult {
  const PaymentResult();

  /// Parse the platform-channel success value. An unknown/absent status settles
  /// defensively to a cancellation so the Future always resolves to exactly one
  /// typed result (never throws).
  factory PaymentResult.fromMap(Map<String, dynamic> map) {
    final payment = SanitizedPayment.fromMap(
      map['payment'] is Map ? Map<String, dynamic>.from(map['payment'] as Map) : null,
    );
    switch (map['status']) {
      case 'confirmed':
        return PaymentConfirmed(payment);
      case 'cancelled':
        return PaymentCancelled(CancelReason.fromWire(map['reason'] as String?), payment);
      case 'expired':
        return PaymentExpired(ExpiredReason.fromWire(map['reason'] as String?), payment);
      case 'failed':
        return PaymentFailed(payment);
      default:
        return PaymentCancelled(CancelReason.dismissed, payment);
    }
  }
}

class PaymentConfirmed extends PaymentResult {
  const PaymentConfirmed(this.payment);
  final SanitizedPayment? payment;
}

class PaymentCancelled extends PaymentResult {
  const PaymentCancelled(this.reason, this.payment);
  final CancelReason reason;
  final SanitizedPayment? payment;
}

class PaymentExpired extends PaymentResult {
  const PaymentExpired(this.reason, this.payment);
  final ExpiredReason reason;
  final SanitizedPayment? payment;
}

class PaymentFailed extends PaymentResult {
  const PaymentFailed(this.payment);
  final SanitizedPayment? payment;
}
