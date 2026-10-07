import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Outcome of a single native send attempt.
class SendOutcome {
  SendOutcome({required this.success, this.error});
  final bool success;
  final String? error;
}

/// Bridges to the native Android SmsManager via a MethodChannel. All SMS
/// are sent through the SIM physically installed in the phone - there is
/// no internet call anywhere in this service.
class SmsService {
  static const _channel = MethodChannel('bulk_sms_sender/sms');

  /// Requests SEND_SMS at runtime. Returns true if granted.
  static Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  static Future<bool> hasSmsPermission() async {
    return await Permission.sms.isGranted;
  }

  /// Optional - only requested if the app needs to enumerate SIM
  /// subscriptions for multi-SIM selection.
  static Future<bool> requestPhoneStatePermission() async {
    final status = await Permission.phone.request();
    return status.isGranted;
  }

  /// Returns a list of available SIM subscriptions, e.g.
  /// [{"subscriptionId": 1, "displayName": "Safaricom", "carrierName": "Safaricom", "slotIndex": 0}, ...]
  /// Empty list if the device has a single SIM or subscriptions can't be
  /// enumerated (e.g. permission not granted).
  static Future<List<Map<String, dynamic>>> getSimSubscriptions() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getSimSubscriptions');
      if (result == null) return [];
      return result
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on PlatformException {
      return [];
    }
  }

  /// Sends a single SMS through the device's SIM using android.telephony.SmsManager.
  /// [subscriptionId] selects a specific SIM on dual-SIM devices; pass -1 to
  /// use the device's default SMS SIM.
  static Future<SendOutcome> sendSms({
    required String phoneNumber,
    required String message,
    int subscriptionId = -1,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('sendSms', {
        'phoneNumber': phoneNumber,
        'message': message,
        'subscriptionId': subscriptionId,
      });
      final success = result?['success'] as bool? ?? false;
      final error = result?['error'] as String?;
      return SendOutcome(success: success, error: error);
    } on PlatformException catch (e) {
      return SendOutcome(success: false, error: e.message ?? e.code);
    } catch (e) {
      return SendOutcome(success: false, error: e.toString());
    }
  }

  /// True if the device currently has at least one usable SIM, as reported
  /// natively via TelephonyManager.simState.
  static Future<bool> hasSimCard() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasSimCard');
      return result ?? true;
    } on PlatformException {
      // If we can't determine SIM state, don't block the user - let the
      // actual send attempt surface the real error instead.
      return true;
    }
  }
}
