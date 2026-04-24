import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'background_sync_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ConnectivityStatus
// ─────────────────────────────────────────────────────────────────────────────

enum ConnectivityStatus { online, offline, unknown }

// ─────────────────────────────────────────────────────────────────────────────
// ConnectivityState
// ─────────────────────────────────────────────────────────────────────────────

class ConnectivityState extends Equatable {
  const ConnectivityState({
    required this.isOnline,
    required this.status,
  });

  factory ConnectivityState.unknown() => const ConnectivityState(
        isOnline: false,
        status: ConnectivityStatus.unknown,
      );

  final bool isOnline;
  final ConnectivityStatus status;

  @override
  List<Object?> get props => [isOnline, status];
}

// ─────────────────────────────────────────────────────────────────────────────
// ConnectivityCubit
// ─────────────────────────────────────────────────────────────────────────────

/// Single source of truth for real-time online/offline status.
///
/// Web-safe: uses only `connectivity_plus` which has full web support.
/// No `dart:io`, no `Platform` references.
class ConnectivityCubit extends Cubit<ConnectivityState> {
  ConnectivityCubit() : super(ConnectivityState.unknown());

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Call once after the cubit is created (e.g. in _BootstrapScreenState.initState).
  Future<void> initialize() async {
    // 1. Determine initial state synchronously before any stream events.
    final initial = await Connectivity().checkConnectivity();
    _emitFromResults(initial);

    // 2. Subscribe to future changes.
    _subscription =
        Connectivity().onConnectivityChanged.listen(_emitFromResults);
  }

  void _emitFromResults(List<ConnectivityResult> results) {
    final wasOnline = state.isOnline;
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    final status =
        isOnline ? ConnectivityStatus.online : ConnectivityStatus.offline;

    emit(ConnectivityState(isOnline: isOnline, status: status));

    // When coming back online, notify BackgroundSyncService so registered
    // listeners (e.g. AppCubit) can flush pending changes.
    if (isOnline && !wasOnline) {
      BackgroundSyncService.instance.notifyOnline();
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
