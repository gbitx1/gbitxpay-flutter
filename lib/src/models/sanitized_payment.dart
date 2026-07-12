import '../enums.dart';

/// Exactly the fields the checkout page emits (serializePayment). `address`,
/// `txHash`, and `externalRef` are intentionally absent — never readable
/// client-side. Amounts are decimal-safe strings. This is UX data only:
/// fulfilment is driven by the signed server webhook.
class SanitizedPayment {
  const SanitizedPayment({
    required this.id,
    required this.status,
    required this.amount,
    required this.currency,
    required this.mode,
    required this.expiresAt,
    this.crypto,
    this.network,
    this.amountCrypto,
    this.amountPaid,
    this.confirmedAt,
  });

  final String id;
  final PaymentStatus status;
  final String amount;
  final String currency;
  final String? crypto;
  final String? network;
  final String? amountCrypto;
  final String? amountPaid;
  final String mode; // "LIVE" | "SANDBOX"
  final String? confirmedAt;
  final String expiresAt;

  /// Re-pick ONLY the 11 whitelisted keys from the platform-channel map; any
  /// other key is discarded (defense in depth against a mutated payload).
  static SanitizedPayment? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final id = map['id'];
    final status = PaymentStatus.fromWire(map['status'] as String?);
    if (id is! String || status == null) return null;
    String? str(Object? v) => v is String ? v : null;
    return SanitizedPayment(
      id: id,
      status: status,
      amount: str(map['amount']) ?? '',
      currency: str(map['currency']) ?? '',
      crypto: str(map['crypto']),
      network: str(map['network']),
      amountCrypto: str(map['amountCrypto']),
      amountPaid: str(map['amountPaid']),
      mode: (map['mode'] == 'LIVE' || map['mode'] == 'SANDBOX') ? map['mode'] as String : 'SANDBOX',
      confirmedAt: str(map['confirmedAt']),
      expiresAt: str(map['expiresAt']) ?? '',
    );
  }
}
