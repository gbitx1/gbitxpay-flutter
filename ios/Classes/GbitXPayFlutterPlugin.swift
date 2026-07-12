import Flutter
import UIKit
import GbitXPay

/// Thin Flutter bridge over the hardened GbitXPay iOS SDK. It performs NO trust
/// work of its own — it forwards configure/present/cancel to `GbitXPay.shared`,
/// which owns the WKWebView, the authenticated-origin gate, and the settle latch.
public class GbitXPayFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = GbitXPayFlutterPlugin()
        let methods = FlutterMethodChannel(name: "com.gbitx.pay/methods", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methods)
        let events = FlutterEventChannel(name: "com.gbitx.pay/events", binaryMessenger: registrar.messenger())
        events.setStreamHandler(instance)
        // Belt-and-suspenders reconciliation on a genuine engine reset. The
        // primary hot-restart path is the Dart-driven `reconcile` call (register
        // is not re-invoked on a Dart isolate restart). Idempotent no-op when
        // nothing is presented.
        Task { @MainActor in GbitXPay.shared.dismissActiveCheckout() }
    }

    // MARK: FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: MethodCallHandler
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "configure": handleConfigure(call, result)
        case "present": handlePresent(call, result)
        case "cancel": handleCancel(result)
        case "reconcile": handleCancel(result) // dismiss any stranded checkout
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func handleConfigure(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let key = args["publishableKey"] as? String ?? ""
        let envString = args["environment"] as? String
        let environment: GbitXPayEnvironment? = envString == "live" ? .live : (envString == "test" ? .test : nil)
        let timeoutMs = args["timeoutMs"] as? Int ?? 10_000
        let apiBase = args["apiBaseUrl"] as? String
        let debug = args["debug"] as? Bool ?? false

        Task { @MainActor in
            do {
                try await GbitXPay.shared.configure(publishableKey: key,
                                                    environment: environment,
                                                    timeout: TimeInterval(timeoutMs) / 1000.0,
                                                    apiBaseURL: apiBase,
                                                    debug: debug)
                result(nil)
            } catch let error as GbitXPayError {
                result(Self.flutterError(error))
            } catch {
                result(Self.flutterError(.serverError))
            }
        }
    }

    private func handlePresent(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let sessionId = args["sessionId"] as? String ?? ""
        let paymentId = args["paymentId"] as? String ?? ""
        let clientToken = args["clientToken"] as? String ?? ""

        Task { @MainActor in
            do {
                let outcome = try await GbitXPay.shared.present(
                    paymentId: paymentId,
                    clientToken: clientToken,
                    from: nil,
                    // onLoaded is derived by Dart from the 'loaded' onEvent below;
                    // emitting a second synthetic 'loaded' here would double-fire it.
                    onLoaded: {},
                    onEvent: { [weak self] event in
                        self?.emit(sessionId, type: Self.eventTypeWire(event.type), payment: Self.serialize(event.payment))
                    }
                )
                result(Self.serialize(result: outcome))
            } catch let error as GbitXPayError {
                result(Self.flutterError(error))
            } catch {
                result(Self.flutterError(.serverError))
            }
        }
    }

    private func handleCancel(_ result: @escaping FlutterResult) {
        Task { @MainActor in
            GbitXPay.shared.dismissActiveCheckout()
            result(nil)
        }
    }

    // MARK: Serialization

    private func emit(_ sessionId: String, type: String, payment: [String: Any]?) {
        var event: [String: Any] = ["type": type]
        if let payment = payment { event["payment"] = payment }
        eventSink?(["sessionId": sessionId, "event": event])
    }

    private static func eventTypeWire(_ type: CheckoutEventType) -> String {
        // Dart expects the short name (loaded/confirmed/…), matching CheckoutEventType.rawValue.
        return type.rawValue
    }

    private static func serialize(result: GbitXPayResult) -> [String: Any] {
        var map: [String: Any]
        let payment: SanitizedPayment?
        switch result {
        case .confirmed(let p):
            map = ["status": "confirmed"]; payment = p
        case .cancelled(let reason, let p):
            map = ["status": "cancelled", "reason": cancelWire(reason)]; payment = p
        case .expired(let reason, let p):
            map = ["status": "expired", "reason": expiredWire(reason)]; payment = p
        case .failed(let p):
            map = ["status": "failed"]; payment = p
        }
        if let serialized = serialize(payment) { map["payment"] = serialized }
        return map
    }

    private static func serialize(_ payment: SanitizedPayment?) -> [String: Any]? {
        guard let p = payment else { return nil }
        var map: [String: Any] = [
            "id": p.id,
            "status": p.status.rawValue,
            "amount": p.amount,
            "currency": p.currency,
            "mode": p.mode,
            "expiresAt": p.expiresAt,
        ]
        if let v = p.crypto { map["crypto"] = v }
        if let v = p.network { map["network"] = v }
        if let v = p.amountCrypto { map["amountCrypto"] = v }
        if let v = p.amountPaid { map["amountPaid"] = v }
        if let v = p.confirmedAt { map["confirmedAt"] = v }
        return map
    }

    private static func cancelWire(_ reason: CancelReason) -> String {
        switch reason {
        case .userClosed: return "user_closed"
        case .dismissed: return "dismissed"
        case .backButton: return "back_button"
        case .loadFailed: return "load_failed"
        }
    }

    private static func expiredWire(_ reason: ExpiredReason) -> String {
        switch reason {
        case .expired: return "expired"
        case .clientBackstop: return "client_backstop"
        }
    }

    private static func flutterError(_ error: GbitXPayError) -> FlutterError {
        var details: [String: Any] = [:]
        if case .onboardingRequired(let status) = error, let s = status { details["onboardingStatus"] = s }
        if case .rateLimited(let sec) = error, let s = sec { details["retryAfterSec"] = s }
        return FlutterError(code: error.code,
                            message: error.errorDescription,
                            details: details.isEmpty ? nil : details)
    }
}
