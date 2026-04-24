import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cbhi_data.dart';

// SharedPreferences keys for persisted UI preferences
const _kLocaleKey = 'cbhi_locale';
const _kDarkModeKey = 'cbhi_dark_mode';

class AppState extends Equatable {
  const AppState({
    required this.snapshot,
    required this.locale,
    required this.isLoading,
    required this.isSyncing,
    this.error,
    this.isDarkMode = false,
  });

  factory AppState.initial() {
    return const AppState(
      snapshot: null,
      locale: Locale('en'),
      isLoading: true,
      isSyncing: false,
      isDarkMode: false,
    );
  }

  final CbhiSnapshot? snapshot;
  final Locale locale;
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final bool isDarkMode;

  AppState copyWith({
    CbhiSnapshot? snapshot,
    Locale? locale,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    bool? isDarkMode,
  }) {
    return AppState(
      snapshot: snapshot ?? this.snapshot,
      locale: locale ?? this.locale,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  @override
  List<Object?> get props => [
    snapshot,
    locale,
    isLoading,
    isSyncing,
    error,
    isDarkMode,
  ];
}

class AppCubit extends Cubit<AppState> {
  AppCubit(this.repository) : super(AppState.initial());

  final CbhiRepository repository;

  @override
  Future<void> close() {
    return super.close();
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      // Restore persisted locale and dark mode preference
      final prefs = await SharedPreferences.getInstance();
      final savedLocale = prefs.getString(_kLocaleKey);
      final savedDark = prefs.getBool(_kDarkModeKey) ?? false;
      final locale = savedLocale != null ? Locale(savedLocale) : const Locale('en');

      final snapshot = await repository.loadCachedSnapshot();
      emit(state.copyWith(
        snapshot: snapshot,
        isLoading: false,
        locale: locale,
        isDarkMode: savedDark,
      ));
    } catch (error) {
      emit(state.copyWith(isLoading: false, error: error.toString()));
    }
  }

  Future<void> sync() async {
    emit(state.copyWith(isSyncing: true, error: null));
    try {
      final householdCode = state.snapshot?.householdCode;
      final snapshot = await repository.sync(
        householdCode?.isEmpty ?? true ? null : householdCode,
      );
      emit(state.copyWith(snapshot: snapshot, isSyncing: false));
    } catch (error) {
      emit(state.copyWith(isSyncing: false, error: error.toString()));
    }
  }

  Future<void> renewCoverage({
    String? paymentMethod,
    String? providerName,
    String? receiptNumber,
  }) async {
    emit(state.copyWith(isSyncing: true, error: null));
    try {
      final snapshot = await repository.renewCoverage(
        paymentMethod: paymentMethod,
        providerName: providerName,
        receiptNumber: receiptNumber,
      );
      emit(state.copyWith(snapshot: snapshot, isSyncing: false));
    } catch (error) {
      emit(state.copyWith(isSyncing: false, error: error.toString()));
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      final notifications = await repository.markNotificationRead(notificationId);
      final currentSnapshot = state.snapshot ?? CbhiSnapshot.empty();
      emit(
        state.copyWith(
          snapshot: currentSnapshot.copyWith(notifications: notifications),
        ),
      );
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
    }
  }

  void setLocale(Locale locale) {
    emit(state.copyWith(locale: locale));
    // Persist locale so it survives app restarts
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_kLocaleKey, locale.languageCode),
    );
  }

  void toggleDarkMode() {
    final newDark = !state.isDarkMode;
    emit(state.copyWith(isDarkMode: newDark));
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_kDarkModeKey, newDark),
    );
  }

  Future<void> refreshFromCache() async {
    final snapshot = await repository.loadCachedSnapshot();
    emit(state.copyWith(snapshot: snapshot));
  }
}
