import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'firebase_options.dart';

import 'src/cbhi_app.dart';
import 'src/cbhi_data.dart';
import 'src/shared/background_sync_service.dart';
import 'src/shared/fcm_service.dart';
import 'src/notifications/fcm_notification_overlay.dart';

/// Background FCM handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled by the OS notification tray automatically
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (required before any Firebase service)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Prevent flutter_animate from crashing when a widget is disposed
  // before its delayed animation fires (e.g., list items that scroll off-screen).
  Animate.restartOnHotReload = false;

  // Catch Flutter framework errors and report rather than crash
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  CbhiRepository? repository;
  Object? initError;

  try {
    try {
      BackgroundSyncService.instance.start();
    } catch (_) {
      // Non-fatal: background sync simply won't fire until the next hot-restart.
    }

    repository = await CbhiRepository.create();
  } catch (e) {
    initError = e;
  }

  if (initError != null || repository == null) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'The app could not start.\n\n$initError\n\nPlease restart the app.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  // Register FCM token after repository is ready
  // Token registration happens after login in cbhi_state.dart
  FcmService.instance.onForegroundMessage((message) {
    // Foreground messages — the app handles these via in-app banners
    debugPrint('[FCM] Foreground: ${message.notification?.title}');
  });

  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment = const String.fromEnvironment(
          'APP_ENV',
          defaultValue: 'production',
        );
        options.tracesSampleRate = 0.1;
        options.attachScreenshot = false;
        options.attachViewHierarchy = false;
        options.beforeBreadcrumb = (breadcrumb, hint) {
          if (breadcrumb?.category == 'navigation') {
            final to = breadcrumb?.data?['to']?.toString() ?? '';
            if (to.contains('otp') || to.contains('payment')) return null;
          }
          return breadcrumb;
        };
      },
      appRunner: () => runApp(
        FcmNotificationOverlay(child: CbhiApp(repository: repository!)),
      ),
    );
  } else {
    runApp(FcmNotificationOverlay(child: CbhiApp(repository: repository)));
  }
}
