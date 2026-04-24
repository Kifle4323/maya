import 'package:flutter/foundation.dart';

/// Callback registry for background sync.
///
/// Previously owned its own `connectivity_plus` stream subscription.
/// Now simplified: `ConnectivityCubit` calls [notifyOnline] when the device
/// comes back online, which fires all registered listeners.
class BackgroundSyncService {
  BackgroundSyncService._();
  static final BackgroundSyncService instance = BackgroundSyncService._();

  final List<AsyncCallback> _listeners = [];

  void addListener(AsyncCallback callback) {
    if (!_listeners.contains(callback)) _listeners.add(callback);
  }

  void removeListener(AsyncCallback callback) {
    _listeners.remove(callback);
  }

  /// Called by [ConnectivityCubit] when the device transitions offline → online.
  /// Fires all registered callbacks silently (errors are swallowed).
  void notifyOnline() {
    for (final cb in List.of(_listeners)) {
      cb().catchError((_) {});
    }
  }

  /// No-op — kept for API compatibility. Connectivity is now managed by
  /// [ConnectivityCubit].
  void start() {}

  /// No-op — kept for API compatibility.
  void stop() {}
}
