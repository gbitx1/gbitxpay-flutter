/// GbitXPay Flutter plugin — accept crypto payments in your Flutter app.
///
/// Wraps the hardened native GbitXPay iOS/Android SDKs (native-wrapping
/// federated plugin), so the WebView, authenticated-origin trust gate, and
/// settle latch are inherited, not re-implemented in Dart. Fulfilment is driven
/// by the signed server webhook — SDK results are UX only.
library gbitx_pay_flutter;

export 'src/enums.dart';
export 'src/errors.dart' show GbitxPayException;
export 'src/gbitx_pay.dart' show GbitxPay;
export 'src/models/checkout_event.dart';
export 'src/models/payment_result.dart';
export 'src/models/sanitized_payment.dart';
