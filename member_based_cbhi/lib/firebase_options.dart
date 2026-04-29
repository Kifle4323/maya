// Firebase configuration for member_based_cbhi.
// Values are injected via --dart-define at build time.
//
// Required dart-define keys:
//   FIREBASE_PROJECT_ID
//   FIREBASE_API_KEY
//   FIREBASE_APP_ID_WEB
//   FIREBASE_MESSAGING_SENDER_ID
//   FIREBASE_STORAGE_BUCKET
//
// Run `flutterfire configure` to auto-generate this file with real values.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'maya-71797',
  );
  static const _apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyCUYIBBQnaR0EzfrPvP7n2qxZZz0rz8ubs',
  );
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '29920872141',
  );
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'maya-71797.firebasestorage.app',
  );
  static const _appIdWeb = String.fromEnvironment(
    'FIREBASE_APP_ID_WEB',
    defaultValue: '1:29920872141:web:994fea511f203782ea8b84',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return web; // Desktop/iOS use web config
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: _apiKey,
    appId: _appIdWeb,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    authDomain: '$_projectId.firebaseapp.com',
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: _apiKey,
    appId: String.fromEnvironment(
      'FIREBASE_APP_ID_ANDROID',
      defaultValue: '1:000000000000:android:0000000000000000000000',
    ),
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );
}
