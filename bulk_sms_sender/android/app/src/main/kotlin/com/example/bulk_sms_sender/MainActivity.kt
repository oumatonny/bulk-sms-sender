package com.example.bulk_sms_sender

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger

/**
 * Native bridge that sends SMS through the SIM physically installed in
 * this Android device using android.telephony.SmsManager. No network
 * request, third-party SDK, or online SMS gateway is used anywhere in
 * this file - messages leave the device only via the cellular radio.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "bulk_sms_sender/sms"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")
                    val subscriptionId = call.argument<Int>("subscriptionId") ?: -1

                    if (phoneNumber.isNullOrBlank() || message.isNullOrEmpty()) {
                        result.success(mapOf("success" to false, "error" to "Missing phone number or message"))
                        return@setMethodCallHandler
                    }
                    sendSms(phoneNumber, message, subscriptionId, result)
                }
                "getSimSubscriptions" -> result.success(getSimSubscriptions())
                "hasSimCard" -> result.success(hasSimCard())
                else -> result.notImplemented()
            }
        }
    }

    /** True if the device reports at least one usable SIM. */
    private fun hasSimCard(): Boolean {
        return try {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            tm.simState == TelephonyManager.SIM_STATE_READY
        } catch (e: Exception) {
            // If we can't determine state reliably, don't block the user -
            // the actual send attempt will surface a real error instead.
            true
        }
    }

    /**
     * Lists available SIM subscriptions for dual-SIM devices. Requires
     * READ_PHONE_STATE; returns an empty list (rather than throwing) if
     * the permission has not been granted, so the caller can fall back to
     * the device's default SMS SIM.
     */
    private fun getSimSubscriptions(): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) return emptyList()
        return try {
            val hasPermission = checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
            if (!hasPermission) return emptyList()

            val subscriptionManager =
                getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
            val subs = subscriptionManager.activeSubscriptionInfoList ?: return emptyList()
            subs.map {
                mapOf(
                    "subscriptionId" to it.subscriptionId,
                    "displayName" to it.displayName?.toString(),
                    "carrierName" to it.carrierName?.toString(),
                    "slotIndex" to it.simSlotIndex
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * Sends [message] to [phoneNumber] via SmsManager, splitting into
     * multiple parts automatically if it exceeds a single SMS's length.
     * Waits for the SENT broadcast(s) for every part before resolving
     * [result], so the caller gets a definitive success/failure outcome
     * for the whole message (not just the first part).
     */
    private fun sendSms(
        phoneNumber: String,
        message: String,
        subscriptionId: Int,
        result: MethodChannel.Result
    ) {
        try {
            val smsManager: SmsManager =
                if (subscriptionId >= 0 && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                    SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
                } else {
                    @Suppress("DEPRECATION")
                    SmsManager.getDefault()
                }

            val parts = smsManager.divideMessage(message)
            val action = "BULK_SMS_SENT_${UUID.randomUUID()}"
            val remaining = AtomicInteger(parts.size)
            val hadError = java.util.concurrent.atomic.AtomicBoolean(false)
            var lastError: String? = null

            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    val ok = resultCode == android.app.Activity.RESULT_OK
                    if (!ok) {
                        hadError.set(true)
                        lastError = smsErrorMessage(resultCode)
                    }
                    if (remaining.decrementAndGet() <= 0) {
                        try {
                            unregisterReceiver(this)
                        } catch (e: Exception) {
                            // Already unregistered - ignore.
                        }
                        runOnUiThread {
                            result.success(
                                mapOf(
                                    "success" to !hadError.get(),
                                    "error" to if (hadError.get()) lastError else null
                                )
                            )
                        }
                    }
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, IntentFilter(action), Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(receiver, IntentFilter(action))
            }

            val sentIntents = ArrayList<PendingIntent>()
            for (i in parts.indices) {
                val pendingIntent = PendingIntent.getBroadcast(
                    this,
                    i,
                    Intent(action).setPackage(packageName),
                    PendingIntent.FLAG_UPDATE_CURRENT or
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
                )
                sentIntents.add(pendingIntent)
            }

            smsManager.sendMultipartTextMessage(phoneNumber, null, parts, sentIntents, null)
        } catch (e: Exception) {
            result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown SMS error")))
        }
    }

    private fun smsErrorMessage(resultCode: Int): String {
        return when (resultCode) {
            SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "Generic failure sending SMS"
            SmsManager.RESULT_ERROR_NO_SERVICE -> "No mobile network service"
            SmsManager.RESULT_ERROR_NULL_PDU -> "Null PDU error"
            SmsManager.RESULT_ERROR_RADIO_OFF -> "Radio is off - check airplane mode"
            else -> "SMS send failed (code $resultCode)"
        }
    }
}
