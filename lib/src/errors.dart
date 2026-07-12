import 'package:flutter/services.dart' show PlatformException;

import 'redact.dart';

/// The single public error type. Terminal payment outcomes (cancelled / expired
/// / failed) are NOT errors — they resolve as a PaymentResult. This is thrown
/// only for SDK or credential faults.
///
/// [code] is a stable machine string; branch on it, never on [message].
class GbitxPayException implements Exception {
  const GbitxPayException(this.code, this.message, {this.onboardingStatus, this.retryAfterSec});

  /// One of: not_configured, invalid_key, secret_key_used, environment_mismatch,
  /// onboarding_required, merchant_suspended, rate_limited, network_error,
  /// server_error, invalid_arguments, host_not_fragment_activity.
  final String code;
  final String message;

  /// Present on `onboarding_required`.
  final String? onboardingStatus;

  /// Present on `rate_limited`.
  final int? retryAfterSec;

  /// Rebuild a typed exception from a platform-channel error. The native side
  /// sets `code` to the stable machine code and puts structured metadata in
  /// `details` ({onboardingStatus} / {retryAfterSec}).
  factory GbitxPayException.fromPlatformException(PlatformException e) {
    final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : const <String, dynamic>{};
    return GbitxPayException(
      e.code,
      // Redact defensively so a caller logging `.message` can never leak a token
      // even if some future native path forwarded a raw error string.
      Redact.secrets(e.message ?? e.code),
      onboardingStatus: details['onboardingStatus'] as String?,
      retryAfterSec: details['retryAfterSec'] is int ? details['retryAfterSec'] as int : null,
    );
  }

  static GbitxPayException invalidArguments(String message) =>
      GbitxPayException('invalid_arguments', message);

  @override
  String toString() => 'GbitxPayException($code): ${Redact.secrets(message)}';
}
