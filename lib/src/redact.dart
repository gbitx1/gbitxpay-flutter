/// Credential hygiene. The publishable key, client token, and any token-bearing
/// URL must never reach a Dart log or a serialized error. These helpers are used
/// defensively; the plugin never logs credentials in the first place.
class Redact {
  const Redact._();

  // Case-insensitive on the pk_/gk_ prefix and the Bearer literal to match the RN
  // SDK's /gi and iOS/Android (a PK_LIVE_… or BEARER … must still scrub). The
  // token/hex bodies are already class-defined; the t= param stays case-sensitive
  // to match RN's non-i on that one.
  static final RegExp _keys = RegExp(r'([gp]k_(live|test)_)[0-9a-fA-F]{6,}', caseSensitive: false);
  static final RegExp _tokenParam = RegExp(r'([#?&]t=)[^\s&"' "'" r']+');
  static final RegExp _bearer = RegExp(r'(Bearer\s+)[^\s"' "'" r']+', caseSensitive: false);

  static String secrets(String input) => input
      .replaceAllMapped(_keys, (m) => '${m.group(1)}redacted')
      .replaceAllMapped(_tokenParam, (m) => '${m.group(1)}redacted')
      .replaceAllMapped(_bearer, (m) => '${m.group(1)}redacted');
}
