import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'biometric_stub.dart'
    if (dart.library.io) 'biometric_native.dart' as impl;
import 'secure_storage_service.dart';

/// Biometric authentication service.
/// Tokens are stored in flutter_secure_storage (encrypted keychain/keystore).
class BiometricService {
  static const _biometricEnabledKey = 'cbhi_biometric_enabled';
  static const _biometricTokenKey = 'cbhi_biometric_token';

  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    return impl.isAvailable();
  }

  static Future<bool> isBiometricEnabled() async {
    final value =
        await SecureStorageService.instance.read(_biometricEnabledKey);
    return value == 'true';
  }

  static Future<bool> enableBiometric(String accessToken) async {
    final available = await isAvailable();
    if (!available) return false;
    final authenticated = await authenticate(
      reason: 'Confirm your identity to enable biometric login',
    );
    if (!authenticated) return false;
    await SecureStorageService.instance.write(_biometricEnabledKey, 'true');
    await SecureStorageService.instance.write(_biometricTokenKey, accessToken);
    return true;
  }

  static Future<void> disableBiometric() async {
    await SecureStorageService.instance.delete(_biometricEnabledKey);
    await SecureStorageService.instance.delete(_biometricTokenKey);
  }

  static Future<String?> authenticateAndGetToken() async {
    final enabled = await isBiometricEnabled();
    if (!enabled) return null;
    final authenticated =
        await authenticate(reason: 'Sign in to Maya City CBHI');
    if (!authenticated) return null;
    return SecureStorageService.instance.read(_biometricTokenKey);
  }

  static Future<bool> authenticate({required String reason}) async {
    if (kIsWeb) return false;
    try {
      return await impl.authenticate(reason: reason);
    } on PlatformException {
      return false;
    }
  }
}
