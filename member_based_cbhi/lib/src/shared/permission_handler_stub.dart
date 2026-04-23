// Web stub — permission_handler has no web implementation.
// All permission requests are no-ops on web; features check kIsWeb before calling.

class PermissionStatus {
  const PermissionStatus._(this._value);
  final int _value;

  static const granted = PermissionStatus._(1);
  static const denied = PermissionStatus._(0);

  bool get isGranted => _value == 1;
  bool get isDenied => _value == 0;
  bool get isPermanentlyDenied => false;
  bool get isRestricted => false;
  bool get isLimited => false;
}

class _PermissionRequest {
  const _PermissionRequest();
  Future<PermissionStatus> request() async => PermissionStatus.granted;
  Future<PermissionStatus> get status async => PermissionStatus.granted;
}

class Permission {
  static const camera = _PermissionRequest();
  static const photos = _PermissionRequest();
  static const storage = _PermissionRequest();
  static const microphone = _PermissionRequest();
  static const location = _PermissionRequest();
}
