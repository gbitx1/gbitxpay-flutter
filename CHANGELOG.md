# Changelog

## 0.1.0 (unreleased)

Initial Flutter plugin for GbitXPay — a native‑wrapping bridge over the hardened iOS/Android SDKs.

- `GbitxPay.instance.configure()` / `present()` / `cancel()`; typed `PaymentResult` (sealed) + `GbitxPayException` (stable `code`).
- MethodChannel (`com.gbitx.pay/methods`) request/response + EventChannel (`com.gbitx.pay/events`) for `onLoaded`/`onEvent`.
- No Dart‑side WebView or trust logic: forwards to the native SDKs which own the authenticated‑origin gate, nav lock, settle latch, and URL building.
- Dart unit tests over result/error mapping, the payment whitelist, the single‑session guard, and redaction.

### Native SDK version map

| gbitx_pay_flutter | iOS `GbitXPay` | Android `com.gbitx:pay-android` |
| --- | --- | --- |
| 0.1.0 | 0.1.0 | 0.1.0 |
