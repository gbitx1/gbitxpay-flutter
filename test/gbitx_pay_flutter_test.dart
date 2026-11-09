import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:gbitx_pay_flutter/gbitx_pay_flutter.dart';
import 'package:gbitx_pay_flutter/src/gbitx_pay_platform_interface.dart';
import 'package:gbitx_pay_flutter/src/redact.dart';

class FakePlatform extends GbitxPayPlatform with MockPlatformInterfaceMixin {
  Map<String, dynamic>? presentResult;
  PlatformException? presentError;
  Completer<void>? gate; // held to keep present() in-flight
  final List<String> cancelled = [];
  final StreamController<Map<String, dynamic>> _events = StreamController.broadcast();

  @override
  Future<void> configure(Map<String, dynamic> args) async {}

  @override
  Future<Map<String, dynamic>> present(Map<String, dynamic> args) async {
    if (gate != null) await gate!.future;
    if (presentError != null) throw presentError!;
    return presentResult!;
  }

  @override
  Future<void> cancel(String sessionId) async => cancelled.add(sessionId);

  @override
  Future<void> reconcile() async {}

  @override
  Stream<Map<String, dynamic>> events() => _events.stream;

  void dispose() => _events.close();
}

void main() {
  late FakePlatform fake;

  setUp(() {
    fake = FakePlatform();
    GbitxPayPlatform.instance = fake;
  });

  tearDown(() => fake.dispose());

  group('PaymentResult.fromMap', () {
    test('maps each terminal status', () {
      expect(PaymentResult.fromMap({'status': 'confirmed'}), isA<PaymentConfirmed>());
      expect(PaymentResult.fromMap({'status': 'failed'}), isA<PaymentFailed>());
      final c = PaymentResult.fromMap({'status': 'cancelled', 'reason': 'user_closed'});
      expect((c as PaymentCancelled).reason, CancelReason.userClosed);
      final e = PaymentResult.fromMap({'status': 'expired', 'reason': 'client_backstop'});
      expect((e as PaymentExpired).reason, ExpiredReason.clientBackstop);
    });

    test('unknown status settles defensively to cancelled', () {
      expect(PaymentResult.fromMap({'status': 'wat'}), isA<PaymentCancelled>());
    });
  });

  group('SanitizedPayment.fromMap', () {
    test('re-picks whitelist and drops extras', () {
      final p = SanitizedPayment.fromMap({
        'id': 'p1', 'status': 'CONFIRMED', 'amount': '10', 'currency': 'USD',
        'mode': 'LIVE', 'expiresAt': 'z',
        'address': 'bc1qevil', 'txHash': 'deadbeef', 'externalRef': 'secret',
      });
      expect(p, isNotNull);
      expect(p!.id, 'p1');
      expect(p.status, PaymentStatus.confirmed);
    });

    test('rejects missing id / bad status', () {
      expect(SanitizedPayment.fromMap({'status': 'CONFIRMED'}), isNull);
      expect(SanitizedPayment.fromMap({'id': 'x', 'status': 'HACKED'}), isNull);
      expect(SanitizedPayment.fromMap(null), isNull);
    });
  });

  group('GbitxPayException', () {
    test('maps a PlatformException by code + details', () {
      final e = GbitxPayException.fromPlatformException(
        PlatformException(code: 'rate_limited', message: 'slow down', details: {'retryAfterSec': 30}),
      );
      expect(e.code, 'rate_limited');
      expect(e.retryAfterSec, 30);
    });

    test('toString never leaks a token', () {
      const e = GbitxPayException('network_error', 'boom https://www.gbitxpay.com/p/x#t=SECRET');
      expect(e.toString().contains('SECRET'), isFalse);
    });
  });

  group('Redact', () {
    test('scrubs keys and token fragments', () {
      final s = Redact.secrets('key=pk_live_${'a' * 64} url=https://x/p/y#t=TOK');
      expect(s.contains('a' * 64), isFalse);
      expect(s.contains('TOK'), isFalse);
      expect(s.contains('pk_live_redacted'), isTrue);
    });
  });

  group('GbitxPay.present', () {
    test('returns the mapped terminal result', () async {
      fake.presentResult = {'status': 'confirmed', 'payment': {'id': 'p1', 'status': 'CONFIRMED', 'amount': '10', 'currency': 'USD', 'mode': 'LIVE', 'expiresAt': 'z'}};
      final r = await GbitxPay.instance.present(paymentId: 'ckpayment12345', clientToken: 'a' * 32);
      expect(r, isA<PaymentConfirmed>());
      expect((r as PaymentConfirmed).payment?.id, 'p1');
    });

    test('rejects a second concurrent present with invalid_arguments', () async {
      fake.gate = Completer<void>();
      fake.presentResult = {'status': 'cancelled', 'reason': 'user_closed'};
      final first = GbitxPay.instance.present(paymentId: 'ckpayment12345', clientToken: 'a' * 32);
      await Future<void>.delayed(Duration.zero);
      expect(
        () => GbitxPay.instance.present(paymentId: 'ckpayment67890', clientToken: 'b' * 32),
        throwsA(isA<GbitxPayException>()),
      );
      fake.gate!.complete();
      await first;
    });

    test('maps a platform error to a typed exception', () async {
      fake.presentError = PlatformException(code: 'not_configured', message: 'configure first');
      expect(
        () => GbitxPay.instance.present(paymentId: 'ckpayment12345', clientToken: 'a' * 32),
        throwsA(predicate((e) => e is GbitxPayException && e.code == 'not_configured')),
      );
    });
  });
}
