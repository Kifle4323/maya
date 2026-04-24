// Firebase configuration for cbhi_admin_desktop.
// Real values are baked in as defaults; can be overridden via --dart-define.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const _apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyCd04uZ9izKUsYpDLQ_6ZEjgf9XtIMCf8k',
  );
  static const _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'maya-city-cbhi',
  );
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '807775792445',
  );
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'maya-city-cbhi.firebasestorage.app',
  );
  static const _appIdWeb = String.fromEnvironment(
    'FIREBASE_APP_ID_WEB',
    defaultValue: '1:807775792445:web:ef4de33dbbc9b63feda954',
  );
  static const _measurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
    defaultValue: 'G-B8WBSQ76ZW',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return web; // Desktop uses web config
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions: unsupported platform.',
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
    measurementId: _measurementId,
  );
}
