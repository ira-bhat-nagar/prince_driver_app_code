import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Lightweight notification service using the Android notification channel
/// via a MethodChannel. No third-party plugin required.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  static const _channel = MethodChannel('com.gorush.driver/notifications');

  static const int _onlineNotifId = 1001;
  static const int _offlineNotifId = 1002;

  /// Show a heads-up notification for going online / offline.
  Future<void> showOnlineStatusNotification({required bool isOnline}) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'id': isOnline ? _onlineNotifId : _offlineNotifId,
        'title': isOnline ? '🟢 GoRush Driver – You are Online' : '🔴 GoRush Driver – You are Offline',
        'body': isOnline
            ? 'Looking for ride requests. Keep the app open to receive requests.'
            : 'You will not receive new ride requests while offline.',
        'channelId': 'gorush_driver_status',
        'channelName': 'Driver Status Alerts',
        'importance': 4,
      });
    } on PlatformException catch (e) {
      debugPrint('[NotificationService] showNotification error: $e');
    } on MissingPluginException {
      debugPrint('[NotificationService] Platform channel not available — notification skipped.');
    }
  }

  /// Show a heads-up notification for a new ride request.
  Future<void> showNewRideRequestNotification() async {
    try {
      await _channel.invokeMethod('showNotification', {
        'id': 2001,
        'title': '🚗 New Ride Request Available!',
        'body': 'Pickup at Sector 62, Noida ➔ Drop at Connaught Place, New Delhi. Tap to accept.',
        'channelId': 'gorush_driver_status',
        'channelName': 'Driver Status Alerts',
        'importance': 4,
      });
    } on PlatformException catch (e) {
      debugPrint('[NotificationService] showNotification error: $e');
    } on MissingPluginException {
      debugPrint('[NotificationService] Platform channel not available — notification skipped.');
    }
  }

  /// 🔔 Play the best system ringtone + vibrate when a new ride request arrives.
  /// Uses Android's built-in RingtoneManager — no extra package needed.
  Future<void> playRideRequestRing() async {
    try {
      await _channel.invokeMethod('playRideRing');
    } on PlatformException catch (e) {
      debugPrint('[NotificationService] playRideRing error: $e');
    } on MissingPluginException {
      debugPrint('[NotificationService] playRideRing: channel not available.');
    }
  }

  /// Stop the ride ring (call after accept/reject).
  Future<void> stopRideRing() async {
    try {
      await _channel.invokeMethod('stopRideRing');
    } catch (_) {}
  }
}
