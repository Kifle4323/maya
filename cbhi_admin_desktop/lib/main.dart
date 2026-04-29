import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/app.dart';
import 'src/data/admin_repository.dart';
import 'src/shared/fcm_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Log all Flutter framework errors to console
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
    };

    // Only block on repository init (fast — just reads SharedPreferences)
    final repository = AdminRepository();
    await repository.init();

    // Start the app immediately — don't wait for Firebase/FCM
    runApp(CbhiAdminApp(repository: repository));

    // Firebase + FCM setup in the background (non-blocking)
    _initFirebaseAndFcm(repository);
  }, (error, stack) {
    debugPrint('[UnhandledAsync] $error\n$stack');
  });
}

/// Firebase and FCM initialization runs after the app is already visible.
/// Failures are non-fatal — the app works without push notifications.
Future<void> _initFirebaseAndFcm(AdminRepository repository) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('[Firebase] Init failed (non-fatal): $e');
    return;
  }

  try {
    final token = await FcmService.instance.init();
    if (token != null && repository.isAuthenticated) {
      await repository.registerFcmToken(token);
    }
  } catch (e) {
    debugPrint('[FCM] Setup failed (non-fatal): $e');
  }

  try {
    FcmService.instance.onTokenRefresh((newToken) async {
      try {
        if (repository.isAuthenticated) {
          await repository.registerFcmToken(newToken);
        }
      } catch (_) {}
    });
  } catch (_) {}

  try {
    FcmService.instance.onForegroundMessage((message) {
      debugPrint('[FCM] Foreground: ${message.notification?.title}');
    });
  } catch (_) {}
}
