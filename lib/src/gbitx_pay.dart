import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;

import 'enums.dart';
import 'errors.dart';
import 'gbitx_pay_platform_interface.dart';
import 'models/checkout_event.dart';
import 'models/payment_result.dart';

/// Accept crypto payments in your Flutter app with GbitXPay.
///
/// Your SERVER creates the payment with your SECRET key and hands the app only
/// `{ paymentId, clientToken }`. The app opens the hosted checkout with a
/// PUBLISHABLE key. Fulfilment is driven by the signed server webhook — a
/// [PaymentConfirmed] result is a UX signal only and can be forged on a
/// compromised device. Never release goods from it.
///
/// This plugin forwards to the hardened native GbitXPay SDKs (iOS/Android),
/// which own the WebView, the authenticated-origin trust gate, and the settle
/// latch. The Dart layer performs no security-sensitive work.
///
/// Android: the host Activity MUST be a `FlutterFragmentActivity` (the native
/// checkout is a DialogFragment). Otherwise [present] throws
/// `host_not_fragment_activity`.
class GbitxPay {
  GbitxPay._();

  static final GbitxPay instance = GbitxPay._();

  int _counter = 0;
  String? _activeSessionId;
  bool _reconciled = false;

  /// Validate the publishable key against the GbitX backend and prepare the SDK.
  /// Must complete before [present]. Safe to call more than once.
  ///
  /// Throws [GbitxPayException] on an invalid/secret key, environment mismatch,
  /// onboarding/suspension, rate limiting, or a network/server failure.
  Future<void> configure({
    required String publishableKey,
    GbitxPayEnvironment? environment,
    Duration timeout = const Duration(seconds: 10),
    String? apiBaseUrl,
    bool debug = false,
  }) async {
    // Once per isolate: clear any native checkout stranded by a Dart hot restart
    // (the old isolate's present() Future is gone but the native sheet may still
    // be up). Best-effort; symmetric across iOS/Android. No-op when nothing open.
    if (!_reconciled) {
      _reconciled = true;
      try {
        await GbitxPayPlatform.instance.reconcile();
      } catch (_) {
        // reconciliation is best-effort; never block configure on it
      }
    }
    try {
      await GbitxPayPlatform.instance.configure(<String, dynamic>{
        'publishableKey': publishableKey,
        'environment': environment?.name,
        'timeoutMs': timeout.inMilliseconds,
        'apiBaseUrl': apiBaseUrl,
        'debug': debug,
      });
    } on PlatformException catch (e) {
      throw GbitxPayException.fromPlatformException(e);
    }
  }

  /// Open the hosted checkout for one payment and resolve its terminal result.
  ///
  /// [paymentId] and [clientToken] come from YOUR server's `POST /v1/payments`
  /// response. Returns a [PaymentResult]; throws [GbitxPayException] only for
  /// SDK/credential faults (a cancelled/expired/failed payment is a normal
  /// result). [onLoaded] fires once when the checkout is interactive; [onEvent]
  /// streams lifecycle events. Both are UX only.
  Future<PaymentResult> present({
    required String paymentId,
    required String clientToken,
    void Function()? onLoaded,
    void Function(CheckoutEvent event)? onEvent,
  }) async {
    if (_activeSessionId != null) {
      throw GbitxPayException.invalidArguments('A checkout is already open.');
    }
    final sessionId = 's_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
    _activeSessionId = sessionId;

    var loadedFired = false;
    StreamSubscription<Map<String, dynamic>>? sub;
    if (onLoaded != null || onEvent != null) {
      sub = GbitxPayPlatform.instance.events().listen((map) {
        if (map['sessionId'] != sessionId) return;
        final event = CheckoutEvent.fromMap(
          map['event'] is Map ? Map<String, dynamic>.from(map['event'] as Map) : null,
        );
        if (event == null) return;
        if (event.type == CheckoutEventType.loaded && !loadedFired) {
          loadedFired = true;
          onLoaded?.call();
        }
        onEvent?.call(event);
      });
    }

    try {
      final map = await GbitxPayPlatform.instance.present(<String, dynamic>{
        'sessionId': sessionId,
        'paymentId': paymentId,
        'clientToken': clientToken,
      });
      return PaymentResult.fromMap(map);
    } on PlatformException catch (e) {
      throw GbitxPayException.fromPlatformException(e);
    } finally {
      await sub?.cancel();
      _activeSessionId = null;
    }
  }

  /// Dismiss the active checkout, if any. The in-flight [present] then resolves
  /// with a [PaymentCancelled] result. No-op when nothing is open.
  Future<void> cancel() async {
    final id = _activeSessionId;
    if (id == null) return;
    try {
      await GbitxPayPlatform.instance.cancel(id);
    } on PlatformException catch (e) {
      throw GbitxPayException.fromPlatformException(e);
    }
  }
}
