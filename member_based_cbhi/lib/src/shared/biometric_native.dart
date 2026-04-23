// Native implementation — local_auth is available here.
import 'package:local_auth/local_auth.dart';

final _auth = LocalAuthentication();

Future<bool> isAvailable() async {
  try {
    final canCheck = await _auth.canCheckBiometrics;
    final isDeviceSupported = await _auth.isDeviceSupported();
    return canCheck && isDeviceSupported;
  } catch (_) {
    return false;
  }
}

Future<bool> authenticate({required String reason}) async {
  return _auth.authenticate(
    localizedReason: reason,
    options: const AuthenticationOptions(
      biometricOnly: false,
      stickyAuth: true,
    ),
  );
}
