import 'dart:async';

import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Platform boundary for the plugin. The default implementation forwards over a
/// MethodChannel (request/response) + EventChannel (streamed UX events) to the
/// native GbitXPay SDKs, which own ALL trust decisions (origin gate, URL build,
/// settle latch). This Dart layer is not security-load-bearing.
abstract class GbitxPayPlatform extends PlatformInterface {
  GbitxPayPlatform() : super(token: _token);

  static final Object _token = Object();
  static GbitxPayPlatform _instance = MethodChannelGbitxPay();

  static GbitxPayPlatform get instance => _instance;

  /// For tests / alternative implementations.
  static set instance(GbitxPayPlatform value) {
    PlatformInterface.verifyToken(value, _token);
    _instance = value;
  }

  Future<void> configure(Map<String, dynamic> args);

  /// Resolves EXACTLY ONCE with the terminal result map
  /// `{status, reason?, payment?}`.
  Future<Map<String, dynamic>> present(Map<String, dynamic> args);

  Future<void> cancel(String sessionId);

  /// Dismiss any checkout left stranded by a previous Dart isolate (hot restart).
  /// No-op when nothing is open.
  Future<void> reconcile();

  /// Broadcast of `{sessionId, event:{type, payment?}}` while a checkout is live.
  Stream<Map<String, dynamic>> events();
}

class MethodChannelGbitxPay extends GbitxPayPlatform {
  static const MethodChannel _methods = MethodChannel('com.gbitx.pay/methods');
  static const EventChannel _events = EventChannel('com.gbitx.pay/events');

  @override
  Future<void> configure(Map<String, dynamic> args) =>
      _methods.invokeMethod<void>('configure', args);

  @override
  Future<Map<String, dynamic>> present(Map<String, dynamic> args) async {
    final result = await _methods.invokeMethod<dynamic>('present', args);
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<void> cancel(String sessionId) =>
      _methods.invokeMethod<void>('cancel', {'sessionId': sessionId});

  @override
  Future<void> reconcile() => _methods.invokeMethod<void>('reconcile');

  @override
  Stream<Map<String, dynamic>> events() =>
      _events.receiveBroadcastStream().map((e) => Map<String, dynamic>.from(e as Map));
}
