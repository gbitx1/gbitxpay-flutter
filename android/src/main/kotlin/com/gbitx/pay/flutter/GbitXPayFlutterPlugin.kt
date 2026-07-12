package com.gbitx.pay.flutter

import androidx.fragment.app.FragmentActivity
import com.gbitx.pay.CancelReason
import com.gbitx.pay.CheckoutEventType
import com.gbitx.pay.Environment
import com.gbitx.pay.ExpiredReason
import com.gbitx.pay.GbitXPay
import com.gbitx.pay.GbitXPayException
import com.gbitx.pay.PaymentResult
import com.gbitx.pay.SanitizedPayment
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Thin Flutter bridge over the hardened GbitXPay Android SDK. It forwards
 * configure/present/cancel to `com.gbitx.pay.GbitXPay`, which owns the WebView,
 * the authenticated `WebMessageListener` origin gate, and the settle latch. The
 * plugin performs no trust work of its own.
 */
class GbitXPayFlutterPlugin :
    FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var activity: FragmentActivity? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods = MethodChannel(binding.binaryMessenger, "com.gbitx.pay/methods")
        methods.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "com.gbitx.pay/events")
        events.setStreamHandler(this)
        // Reconcile any checkout stranded by a Dart hot restart (the old isolate's
        // present() Future is gone but the native sheet may still be up). No-op
        // when nothing is open. This runs on a genuine fresh engine attach.
        GbitXPay.dismissActiveCheckout()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        scope.cancel()
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) { eventSink = sink }
    override fun onCancel(arguments: Any?) { eventSink = null }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }

    // Keep the native session alive across a config change (the native
    // GbitXPayController survives it); just drop our Activity reference.
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onDetachedFromActivity() { activity = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> configure(call, result)
            "present" -> present(call, result)
            "cancel" -> cancel(result)
            "reconcile" -> { GbitXPay.dismissActiveCheckout(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    private fun configure(call: MethodCall, result: MethodChannel.Result) {
        val environment = when (call.argument<String>("environment")) {
            "live" -> Environment.LIVE
            "test" -> Environment.TEST
            else -> null
        }
        scope.launch {
            try {
                GbitXPay.configure(
                    publishableKey = call.argument<String>("publishableKey") ?: "",
                    environment = environment,
                    timeoutMs = call.argument<Number>("timeoutMs")?.toLong() ?: 10_000L,
                    apiBaseUrl = call.argument<String>("apiBaseUrl"),
                    debug = call.argument<Boolean>("debug") ?: false,
                )
                result.success(null)
            } catch (e: GbitXPayException) {
                result.error(e.code, e.message, detailsOf(e))
            } catch (e: Throwable) {
                // Never forward a raw throwable message across the channel — it
                // could contain a token-bearing URL. Fixed, safe message only.
                result.error("server_error", "GbitXPay encountered an unexpected error.", null)
            }
        }
    }

    private fun present(call: MethodCall, result: MethodChannel.Result) {
        val host = activity
        if (host == null) {
            result.error(
                "host_not_fragment_activity",
                "GbitXPay requires the host Activity to be a FlutterFragmentActivity. Make your MainActivity extend FlutterFragmentActivity.",
                null,
            )
            return
        }
        val sessionId = call.argument<String>("sessionId") ?: ""
        val paymentId = call.argument<String>("paymentId") ?: ""
        val clientToken = call.argument<String>("clientToken") ?: ""
        scope.launch {
            try {
                val outcome = GbitXPay.present(
                    activity = host,
                    paymentId = paymentId,
                    clientToken = clientToken,
                    // onLoaded is derived by Dart from the 'loaded' onEvent below;
                    // emitting a second synthetic 'loaded' here would double-fire it.
                    onLoaded = {},
                    onEvent = { event -> emit(sessionId, eventTypeWire(event.type), serialize(event.payment)) },
                )
                result.success(serialize(outcome))
            } catch (e: GbitXPayException) {
                result.error(e.code, e.message, detailsOf(e))
            } catch (e: Throwable) {
                result.error("server_error", "GbitXPay encountered an unexpected error.", null)
            }
        }
    }

    private fun cancel(result: MethodChannel.Result) {
        GbitXPay.dismissActiveCheckout()
        result.success(null)
    }

    // MARK: serialization (delivered on the main thread by the native SDK)

    private fun emit(sessionId: String, type: String, payment: Map<String, Any?>?) {
        // Omit the payment key when null (matches the iOS wire shape byte-for-byte).
        val event = mutableMapOf<String, Any?>("type" to type)
        if (payment != null) event["payment"] = payment
        eventSink?.success(mapOf("sessionId" to sessionId, "event" to event))
    }

    // Wire strings are pinned explicitly (not derived from enum names) so the
    // method-channel contract is a single source of truth that can't drift if a
    // native enum is renamed. Exhaustive `when` forces a decision on any new case.
    private fun eventTypeWire(type: CheckoutEventType): String = when (type) {
        CheckoutEventType.LOADED -> "loaded"
        CheckoutEventType.CONFIRMED -> "confirmed"
        CheckoutEventType.CANCELLED -> "cancelled"
        CheckoutEventType.EXPIRED -> "expired"
        CheckoutEventType.FAILED -> "failed"
        CheckoutEventType.CLOSED -> "closed"
    }

    private fun cancelWire(reason: CancelReason): String = when (reason) {
        CancelReason.USER_CLOSED -> "user_closed"
        CancelReason.DISMISSED -> "dismissed"
        CancelReason.BACK_BUTTON -> "back_button"
        CancelReason.LOAD_FAILED -> "load_failed"
    }

    private fun expiredWire(reason: ExpiredReason): String = when (reason) {
        ExpiredReason.EXPIRED -> "expired"
        ExpiredReason.CLIENT_BACKSTOP -> "client_backstop"
    }

    private fun resultMap(status: String, reason: String?, payment: SanitizedPayment?): Map<String, Any?> {
        // Omit null reason/payment keys (matches iOS's omit-when-null wire shape).
        val map = mutableMapOf<String, Any?>("status" to status)
        if (reason != null) map["reason"] = reason
        serialize(payment)?.let { map["payment"] = it }
        return map
    }

    private fun serialize(result: PaymentResult): Map<String, Any?> = when (result) {
        is PaymentResult.Confirmed -> resultMap("confirmed", null, result.payment)
        is PaymentResult.Cancelled -> resultMap("cancelled", cancelWire(result.reason), result.payment)
        is PaymentResult.Expired -> resultMap("expired", expiredWire(result.reason), result.payment)
        is PaymentResult.Failed -> resultMap("failed", null, result.payment)
    }

    private fun serialize(payment: SanitizedPayment?): Map<String, Any?>? {
        if (payment == null) return null
        // Omit null optional fields so the wire map matches the iOS serializer
        // byte-for-byte (iOS uses `if let`). The six always-present fields first.
        val map = mutableMapOf<String, Any?>(
            "id" to payment.id,
            "status" to payment.status.wire,
            "amount" to payment.amount,
            "currency" to payment.currency,
            "mode" to payment.mode,
            "expiresAt" to payment.expiresAt,
        )
        payment.crypto?.let { map["crypto"] = it }
        payment.network?.let { map["network"] = it }
        payment.amountCrypto?.let { map["amountCrypto"] = it }
        payment.amountPaid?.let { map["amountPaid"] = it }
        payment.confirmedAt?.let { map["confirmedAt"] = it }
        return map
    }

    private fun detailsOf(e: GbitXPayException): Map<String, Any?>? = when (e) {
        is GbitXPayException.OnboardingRequired -> e.onboardingStatus?.let { mapOf("onboardingStatus" to it) }
        is GbitXPayException.RateLimited -> e.retryAfterSec?.let { mapOf("retryAfterSec" to it) }
        else -> null
    }
}
