import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/ride_model.dart';

/// Lightweight notification service using the Android notification channel
/// via a MethodChannel. No third-party plugin required.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  static const _channel = MethodChannel('com.gorush.driver/notifications');

  static const int _onlineNotifId = 1001;
  static const int _offlineNotifId = 1002;

  Future<bool> requestPermission() async {
    try {
      return await _channel
              .invokeMethod<bool>('requestNotificationPermission') ??
          false;
    } on PlatformException catch (error) {
      debugPrint('[NotificationService] permission request error: $error');
      return false;
    } on MissingPluginException {
      debugPrint('[NotificationService] permission channel unavailable.');
      return false;
    }
  }

  /// Show a heads-up notification for going online / offline.
  Future<void> showOnlineStatusNotification({required bool isOnline}) async {
    try {
      if (isOnline && !await requestPermission()) return;
      await _channel.invokeMethod('showNotification', {
        'id': isOnline ? _onlineNotifId : _offlineNotifId,
        'title': isOnline
            ? '🟢 GoRush Driver – You are Online'
            : '🔴 GoRush Driver – You are Offline',
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
      debugPrint(
          '[NotificationService] Platform channel not available — notification skipped.');
    }
  }

  /// Show a heads-up notification for a new ride request.
  Future<void> showNewRideRequestNotification(RideModel ride) async {
    try {
      if (!await requestPermission()) return;
      await _channel.invokeMethod('showNotification', {
        'id': 2001,
        'title': 'New ride request — ${ride.passengerName}',
        'body':
            'Pickup: ${ride.pickupAddress}. Fare ₹${ride.totalFare.toStringAsFixed(0)}. Tap to view.',
        'channelId': 'gorush_driver_status',
        'channelName': 'Driver Status Alerts',
        'importance': 4,
      });
    } on PlatformException catch (e) {
      debugPrint('[NotificationService] showNotification error: $e');
    } on MissingPluginException {
      debugPrint(
          '[NotificationService] Platform channel not available — notification skipped.');
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
