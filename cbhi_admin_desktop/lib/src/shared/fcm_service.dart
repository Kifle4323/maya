import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM service for the admin desktop/web app.
/// Handles token acquisition, foreground messages, and token refresh.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  // VAPID key from Firebase Console → Project Settings → Cloud Messaging → Web Push certificates
  static const _vapidKey = String.fromEnvironment(
    'FIREBASE_VAPID_KEY',
    defaultValue: 'BMlhBo8Og4iuMoZAH2o39T6C_P3swvEfzcmN2brA37t-EtpAH8K5SwBZ2da7dRraWZRkKsG2nQHOT4R-NX_t91U',
  );

  /// Initialize FCM and return the device/browser token.
  /// Returns null if permission is denied or token fetch fails.
  Future<String?> init() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (required on iOS/macOS/web)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Notification permission denied');
        return null;
      }

      // Get token — web requires VAPID key for push subscription
      String? token;
      try {
        if (kIsWeb && _vapidKey.isNotEmpty) {
          token = await messaging.getToken(vapidKey: _vapidKey);
        } else if (!kIsWeb) {
          token = await messaging.getToken();
        }
        // If web and no VAPID key, skip token (notifications won't work but app won't crash)
      } catch (e) {
        debugPrint('[FCM] Token fetch failed: $e');
        return null;
      }

      if (token != null) {
        debugPrint('[FCM] Token acquired: ${token.substring(0, 20)}...');
      }

      // Show notifications while app is in foreground
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      return token;
    } catch (e) {
      debugPrint('[FCM] Init failed: $e');
      return null;
    }
  }

  /// Listen for token rotation (Firebase rotates tokens periodically)
  void onTokenRefresh(Future<void> Function(String token) handler) {
    FirebaseMessaging.instance.onTokenRefresh.listen(
      handler,
      onError: (e) => debugPrint('[FCM] Token refresh error: $e'),
    );
  }

  /// Listen for messages while app is in foreground
  void onForegroundMessage(void Function(RemoteMessage message) handler) {
    FirebaseMessaging.onMessage.listen(
      handler,
      onError: (e) => debugPrint('[FCM] Foreground message error: $e'),
    );
  }

  /// Listen for notification taps that open the app
  void onNotificationTap(void Function(RemoteMessage message) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen(
      handler,
      onError: (e) => debugPrint('[FCM] Notification tap error: $e'),
    );
  }
}
