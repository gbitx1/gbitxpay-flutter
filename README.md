# gbitx_pay_flutter

Accept crypto payments in your Flutter app with **GbitXPay**. Opens the hosted GbitX checkout and returns one typed result.

This plugin is a thin **native‑wrapping** bridge: it forwards to the hardened native GbitXPay **iOS** and **Android** SDKs, so the WebView, the authenticated‑origin trust gate, the navigation lock, and the settle latch are **inherited**, not re‑implemented in Dart. The Dart layer does no security‑sensitive work.

> **Read this first.** Fulfilment is driven **only** by the signed server webhook. A `PaymentConfirmed` result is a UX signal — it can be forged on a compromised device. Never release goods from it.

## How it works

Your **server** creates the payment with your **secret** key (`gk_`) and hands the app only `{ paymentId, clientToken }`. The app opens the checkout with a **publishable** key (`pk_`). The signed `PAYMENT_CONFIRMED` webhook is the source of truth.

Two hosts are involved: the SDK validates your publishable key against the API host `gateway.gbitx.com`, which returns the separate, pinned checkout origin `pay.gbitx.com` that the native WebView locks to. They are intentionally different hosts. (`doc.gbitx.com` is the docs site.)

## Install

```yaml
dependencies:
  gbitx_pay_flutter: ^0.1.0
```

Then `flutter pub get`. The native SDKs resolve automatically — Android pulls `com.gbitx:pay-android` from Maven Central, iOS pulls the `GbitXPay` pod from CocoaPods trunk on `pod install`. No extra registry setup is needed.

### Android — required

The native checkout is a `DialogFragment`, so your host Activity **must** be a `FlutterFragmentActivity`:

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

Otherwise `present()` throws `host_not_fragment_activity`. minSdk 23.

### iOS

iOS 15+. No Podfile changes needed — the `GbitXPay` pod is resolved from CocoaPods trunk automatically.

## Usage

```dart
import 'package:gbitx_pay_flutter/gbitx_pay_flutter.dart';

// once, e.g. at startup
await GbitxPay.instance.configure(publishableKey: 'pk_live_…');

// per payment — paymentId + clientToken come from YOUR server
final result = await GbitxPay.instance.present(paymentId: paymentId, clientToken: clientToken);

switch (result) {
  case PaymentConfirmed():  showThankYou();   // UX only — fulfil via the webhook
  case PaymentCancelled():  break;
  case PaymentExpired():    break;
  case PaymentFailed():     break;
}
```

Optional progress callbacks (UX only):

```dart
await GbitxPay.instance.present(
  paymentId: paymentId,
  clientToken: clientToken,
  onLoaded: () => setState(() => loading = false),
  onEvent: (e) => debugPrint('checkout: ${e.type}'),
);
```

Dismiss programmatically: `await GbitxPay.instance.cancel();` (the in‑flight `present()` then resolves `PaymentCancelled`).

## Your server: creating the payment

```bash
curl https://gateway.gbitx.com/v1/payments \
  -H "Authorization: Bearer $GBITX_SECRET_KEY" \
  -H "Content-Type: application/json" \
  -d '{"amount": 49.99, "currency": "USD", "description": "Order #1234"}'
# → { "payment": { "id": "...", "clientToken": "...", ... } }
```

Send only `{ paymentId, clientToken }` to the app. Fulfil the order from the signed webhook.

## Errors

`configure()`/`present()` throw `GbitxPayException` for SDK/credential faults (a cancelled/expired/failed **payment** is a normal `PaymentResult`, not an exception). Branch on `exception.code`: `not_configured`, `invalid_key`, `secret_key_used`, `environment_mismatch`, `onboarding_required`, `merchant_suspended`, `rate_limited`, `network_error`, `server_error`, `invalid_arguments`, `host_not_fragment_activity`.

## Store policy

Crypto is permitted for **physical goods** and **real‑world services**. **Digital goods/services consumed in‑app must use Apple IAP / Google Play Billing** — don't use this SDK for those.

## License

MIT © GBIT TECHNOLOGIES LIMITED COMPANY. See [SECURITY.md](SECURITY.md) for the trust model and residual risks.
