import '../enums.dart';
import 'sanitized_payment.dart';

/// A streamed lifecycle event (UX/analytics only) delivered while a checkout is
/// in flight. Never use it to fulfil — the signed server webhook is the source
/// of truth.
class CheckoutEvent {
  const CheckoutEvent(this.type, this.payment);

  final CheckoutEventType type;
  final SanitizedPayment? payment;

  static CheckoutEvent? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final type = CheckoutEventType.fromWire(map['type'] as String?);
    if (type == null) return null;
    final payment = SanitizedPayment.fromMap(
      map['payment'] is Map ? Map<String, dynamic>.from(map['payment'] as Map) : null,
    );
    return CheckoutEvent(type, payment);
  }
}
