# Security

`gbitx_pay_flutter` is a **native‑wrapping** plugin: it forwards to the hardened native GbitXPay iOS and Android SDKs and re‑implements **no** WebView, trust gate, navigation lock, URL building, or settle logic in Dart. The security posture is therefore **inherited** from the audited native SDKs.

## The one invariant

**Fulfilment is driven only by the signed server webhook** (`PAYMENT_CONFIRMED`) or a server‑side `GET /v1/payments/:id` with your **secret** key. A `PaymentConfirmed` result is a UX signal, not proof of payment. This bounds the blast radius of every residual risk.

## Why native‑wrap (and not a Dart WebView)

`webview_flutter`'s `JavaScriptChannel` exposes only a string message with **no authenticated sender origin** and is injected into **all** frames — structurally the fail‑open posture the native Android SDK deliberately **refuses** (it requires `WebViewCompat.addWebMessageListener` with an authenticated `sourceOrigin` + `allowedOriginRules`, failing closed otherwise). Re‑implementing the checkout in Dart would ship a weaker gate and a second security surface to audit. So the plugin inherits the native trust root instead.

## What is enforced (in native, inherited here)

- Pinned/frozen checkout origin; exact‑origin navigation lock that opens nothing externally.
- Authenticated per‑message origin gate (iOS `frameInfo.securityOrigin`, Android `WebMessageListener` `sourceOrigin`) + committed `/p/` path + `paymentId` binding.
- Single settle latch across every dismissal path + a fixed 65‑minute client backstop (just beyond the 60‑minute server payment expiry).
- Full WebView lockdown; the client token rides only in the URL fragment (built in native) and never crosses the method channel except once, inbound, on `present`.
- No secret key ever; the publishable key and client token are never logged (Dart or native).

## The Dart boundary is not a trust boundary

Any Dart code in the host app can call `configure` / `present` / `cancel` over the method channel. That is safe **because** the native SDK performs the real, unspoofable origin gating and builds the checkout URL itself — a patched Dart binary cannot forge a terminal result, repoint the checkout origin, or alter `embed=native`. The Dart layer only forwards `{ paymentId, clientToken }` and de‑serializes a result map.

## Residual risks (inherited)

1. **A compromised checkout origin can emit a forged `PaymentConfirmed`.** Mitigation: webhook‑is‑truth. TLS + the origin lock prevent MITM.
2. **Android sub‑frame navigations** aren't reliably gated (platform limitation); the page ships no iframes and mixed content is blocked. Defense in depth belongs in the page CSP.
3. **iOS App‑Bound Domains** and **TLS pinning** are optional native hardening, off by default.
4. **Hot restart**: a Dart hot restart discards the `present()` Future while a native sheet may still be up; the plugin best‑effort dismisses a stranded checkout on the next engine attach. Reconcile via webhook regardless.

## Reporting a vulnerability

Email **security@gbitx.com**. Please do not open a public issue.
