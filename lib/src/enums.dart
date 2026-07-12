/// Live or test environment (inferred from the publishable key prefix and
/// cross-checked with the server by the native SDK).
enum GbitxPayEnvironment { live, test }

/// Mirrors the server PaymentStatus enum (wire strings are UPPER_SNAKE).
enum PaymentStatus {
  pending('PENDING'),
  awaitingPayment('AWAITING_PAYMENT'),
  underpaid('UNDERPAID'),
  confirming('CONFIRMING'),
  confirmed('CONFIRMED'),
  expired('EXPIRED'),
  failed('FAILED'),
  cancelled('CANCELLED');

  const PaymentStatus(this.wire);
  final String wire;

  static PaymentStatus? fromWire(String? value) {
    for (final s in PaymentStatus.values) {
      if (s.wire == value) return s;
    }
    return null;
  }
}

/// Why a checkout ended without a confirmation (UX/analytics only).
enum CancelReason {
  userClosed('user_closed'),
  dismissed('dismissed'),
  backButton('back_button'),
  loadFailed('load_failed');

  const CancelReason(this.wire);
  final String wire;

  static CancelReason fromWire(String? value) {
    for (final r in CancelReason.values) {
      if (r.wire == value) return r;
    }
    return CancelReason.dismissed;
  }
}

enum ExpiredReason {
  expired('expired'),
  clientBackstop('client_backstop');

  const ExpiredReason(this.wire);
  final String wire;

  static ExpiredReason fromWire(String? value) {
    for (final r in ExpiredReason.values) {
      if (r.wire == value) return r;
    }
    return ExpiredReason.expired;
  }
}

enum CheckoutEventType {
  loaded,
  confirmed,
  cancelled,
  expired,
  failed,
  closed;

  static CheckoutEventType? fromWire(String? value) {
    for (final t in CheckoutEventType.values) {
      if (t.name == value) return t;
    }
    return null;
  }
}
