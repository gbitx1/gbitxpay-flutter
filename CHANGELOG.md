# Changelog

## 0.2.0 (2026-11-09)

- Default API base is now `https://api.gbitxpay.com` (GbitXPay moved to its own domain). Earlier versions default to `https://gateway.gbitx.com`, which is being retired, so upgrade to keep receiving payments.
- The checkout origin is still whatever `GET /v1/sdk/config` returns (now `https://www.gbitxpay.com`); nothing to configure.
- Docs and homepage: `https://doc.gbitxpay.com`.

## 0.1.0 (2026-07-13)

Initial Flutter plugin for GbitXPay — a native‑wrapping bridge over the hardened iOS/Android SDKs.

- `GbitxPay.instance.configure()` / `present()` / `cancel()`; typed `PaymentResult` (sealed) + `GbitxPayException` (stable `code`).
- MethodChannel (`com.gbitx.pay/methods`) request/response + EventChannel (`com.gbitx.pay/events`) for `onLoaded`/`onEvent`.
- No Dart‑side WebView or trust logic: forwards to the native SDKs which own the authenticated‑origin gate, nav lock, settle latch, and URL building.
- Dart unit tests over result/error mapping, the payment whitelist, the single‑session guard, and redaction.

### Native SDK version map

| gbitx_pay_flutter | iOS `GbitXPay` | Android `com.gbitx:pay-android` |
| --- | --- | --- |
| 0.2.0 | 0.2.0 | 0.2.0 |
| 0.1.0 | 0.1.0 | 0.1.0 |
