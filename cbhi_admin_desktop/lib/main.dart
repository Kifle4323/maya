import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/app.dart';
import 'src/data/admin_repository.dart';
import 'src/shared/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase — catches errors so a bad config doesn't crash the app
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[Firebase] Init failed: $e');
  }

  final repository = AdminRepository();
  await repository.init();

  // Initialize FCM and register token with backend
  try {
    final token = await FcmService.instance.init();
    if (token != null && repository.isAuthenticated) {
      await repository.registerFcmToken(token);
    }
  } catch (e) {
    debugPrint('[FCM] Setup failed (non-fatal): $e');
  }

  // Re-register token on refresh
  FcmService.instance.onTokenRefresh((newToken) async {
    try {
      if (repository.isAuthenticated) {
        await repository.registerFcmToken(newToken);
      }
    } catch (_) {}
  });

  // Handle foreground notifications — show snackbar via overlay
  FcmService.instance.onForegroundMessage((message) {
    debugPrint('[FCM] Foreground: ${message.notification?.title}');
    // NotificationOverlay.show() can be wired here once the app is running
  });

  runApp(CbhiAdminApp(repository: repository));
}
