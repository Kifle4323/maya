import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cbhi_data.dart';
import 'models/personal_info_model.dart';
import 'models/identity_model.dart';
import 'models/membership_type.dart';

part 'registration_state.dart';

/// Key used to persist in-progress registration across app restarts.
const _kDraftKey = 'cbhi_registration_draft';

class RegistrationCubit extends Cubit<RegistrationState> {
  RegistrationCubit(this.repository) : super(const RegistrationState());

  final CbhiRepository repository;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Called once on app start (from RegistrationFlow.initState).
  /// Restores any in-progress registration draft so the user doesn't lose work
  /// after the app is killed or backgrounded.
  Future<void> startRegistration() async {
    final draft = await _loadDraft();
    if (draft != null && draft.currentStep != RegistrationStep.start) {
      emit(draft);
    } else {
      emit(state.copyWith(currentStep: RegistrationStep.personalInfo, clearError: true));
    }
  }

  // ── Step navigation ────────────────────────────────────────────────────────

  void submitPersonalInfo(PersonalInfoModel info) {
    final next = state.copyWith(
      personalInfo: info,
      currentStep: RegistrationStep.confirmation,
      clearError: true,
    );
    emit(next);
    _saveDraft(next);
  }

  void goBackToPersonalInfo() {
    final next = state.copyWith(
      currentStep: RegistrationStep.personalInfo,
      clearError: true,
    );
    emit(next);
    _saveDraft(next);
  }

  void goBackToConfirmation() {
    final next = state.copyWith(
      currentStep: RegistrationStep.confirmation,
      clearError: true,
    );
    emit(next);
    _saveDraft(next);
  }

  void goBackToIdentity() {
    final next = state.copyWith(
      currentStep: RegistrationStep.identity,
      clearError: true,
    );
    emit(next);
    _saveDraft(next);
  }

  void confirmPersonalInfo() {
    final next = state.copyWith(
      currentStep: RegistrationStep.identity,
      clearError: true,
    );
    emit(next);
    _saveDraft(next);
  }

  void submitIdentity(IdentityModel identityData) {
    final next = state.copyWith(
      identity: identityData,
      currentStep: RegistrationStep.membership,
      clearError: true,
    );
    emit(next);
    _saveDraft(next);
  }

  Future<void> submitPayingMembership(MembershipSelection membership) async {
    await _runRegistration(membership, const []);
  }

  /// Navigate to the payment step for paying members who chose "Pay Now".
  Future<void> beginPayment(MembershipSelection membership) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    // Run registration first to get the snapshot, then show payment
    try {
      final snapshot = await repository.registerFull(
        personalInfo: state.personalInfo!,
        identity: state.identity!,
        membership: membership,
        indigentProofPaths: const [],
      );
      final next = state.copyWith(
        membership: membership,
        registrationSnapshot: snapshot,
        registeredPhone: state.personalInfo?.phone,
        currentStep: RegistrationStep.payment,
        isLoading: false,
        clearError: true,
      );
      emit(next);
      _saveDraft(next);
    } catch (e) {
      final message = _parseErrorMessage(e.toString());
      if (e.toString().contains('400') || e.toString().contains('Bad Request')) {
        emit(state.copyWith(errorMessage: message, isLoading: false));
        return;
      }
      // Network error — build offline snapshot and go to payment anyway
      final offlineSnapshot = _buildOfflineSnapshot(membership);
      await repository.localDb.writeSnapshot(offlineSnapshot);
      final next = state.copyWith(
        membership: membership,
        registrationSnapshot: offlineSnapshot,
        registeredPhone: state.personalInfo?.phone,
        currentStep: RegistrationStep.payment,
        isLoading: false,
        isOffline: true,
        clearError: true,
      );
      emit(next);
      _saveDraft(next);
    }
  }

  void beginIndigentProof(MembershipSelection membership) {    final next = state.copyWith(
      membership: membership,
      currentStep: RegistrationStep.indigentProof,
      clearError: true,
    );
    emit(next);
    _saveDraft(next);
  }

  void cancelIndigentProof() {
    final next = state.copyWith(
      currentStep: RegistrationStep.membership,
      clearMembership: true,
      clearError: true,
    );
    emit(next);
    _saveDraft(next);
  }

  Future<void> submitIndigentProofs(List<String> proofPaths) async {
    final membership = state.membership;
    if (membership == null) {
      emit(state.copyWith(errorMessage: 'Membership selection missing.'));
      return;
    }
    if (proofPaths.isEmpty) {
      emit(state.copyWith(
        errorMessage: 'Add at least one supporting document for indigent membership.',
      ));
      return;
    }
    await _runRegistration(membership, proofPaths);
  }

  void submitPaymentSuccess() {
    final next = state.copyWith(
      currentStep: RegistrationStep.completed,
      clearError: true,
    );
    emit(next);
    _saveDraft(next);
  }

  // ── Registration submission ────────────────────────────────────────────────

  Future<void> _runRegistration(
    MembershipSelection membership,
    List<String> indigentProofPaths,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true, errorMessage: null));

    // Generate 6-digit setup code immediately — shown regardless of online/offline
    final setupCode = _generateTempPassword();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cbhi_setup_code', setupCode);
    await prefs.setString('cbhi_temp_password', setupCode); // keep legacy key for profile screen compat
    await prefs.setBool('cbhi_has_temp_password', true);
    final phone = state.personalInfo?.phone;
    if (phone != null && phone.isNotEmpty) {
      await prefs.setString('cbhi_registered_phone', phone);
    }

    CbhiSnapshot? snapshot;
    bool isOffline = false;

    try {
      snapshot = await repository.registerFull(
        personalInfo: state.personalInfo!,
        identity: state.identity!,
        membership: membership,
        indigentProofPaths: indigentProofPaths,
      );
    } catch (e) {
      // Parse clean message from backend error JSON
      final message = _parseErrorMessage(e.toString());
      // If it's a 400 (validation/duplicate), surface it — don't go offline
      if (e.toString().contains('400') || e.toString().contains('Bad Request')) {
        emit(state.copyWith(errorMessage: message, isLoading: false));
        return;
      }
      // Network/server error — use offline snapshot so dashboard still opens
      isOffline = true;
      snapshot = _buildOfflineSnapshot(membership);
      await repository.localDb.writeSnapshot(snapshot);
    }

    // Inject setup code notification into the snapshot so it appears in the inbox
    final setupCodeNotification = {
      'id': 'setup-code-${DateTime.now().millisecondsSinceEpoch}',
      'type': 'SYSTEM_ALERT',
      'title': 'Your Setup Code',
      'body': 'Your 6-digit setup code is: $setupCode. Use this to set your password in Profile \u2192 Change Password.',
      'isRead': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
    final existingNotifications = List<Map<String, dynamic>>.from(snapshot.notifications);
    existingNotifications.insert(0, setupCodeNotification);
    snapshot = snapshot.copyWith(notifications: existingNotifications);
    await repository.localDb.writeSnapshot(snapshot);

    final next = state.copyWith(
      membership: membership,
      registrationSnapshot: snapshot,
      currentStep: RegistrationStep.completed,
      registeredPhone: state.personalInfo?.phone,
      isLoading: false,
      isOffline: isOffline,
      clearError: true,
    );
    emit(next);
    if (!isOffline) await _clearDraft();
  }

  /// Generates a random 6-digit numeric password
  String _generateTempPassword() {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    return random.toString().padLeft(6, '0');
  }

  /// Extracts a clean human-readable message from a backend error string.
  /// Backend errors look like: Request failed for /path: {"statusCode":400,"message":"..."}
  String _parseErrorMessage(String raw) {
    try {
      // Find JSON object in the error string
      final start = raw.indexOf('{');
      if (start != -1) {
        final jsonStr = raw.substring(start);
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        final msg = decoded['message'];
        if (msg is String && msg.isNotEmpty) return msg;
        if (msg is List && msg.isNotEmpty) return msg.join(', ');
      }
    } catch (_) {}
    // Fallback: strip the path prefix
    final colonIdx = raw.indexOf(':');
    if (colonIdx != -1 && colonIdx < raw.length - 1) {
      final after = raw.substring(colonIdx + 1).trim();
      if (after.isNotEmpty && !after.startsWith('{')) return after;
    }
    return raw;
  }

  CbhiSnapshot _buildOfflineSnapshot(MembershipSelection membership) {
    final info = state.personalInfo!;
    return CbhiSnapshot(
      household: {
        'householdCode': 'LOCAL-${DateTime.now().millisecondsSinceEpoch}',
        'coverageStatus': 'PENDING_RENEWAL',
        'membershipType': membership.type.name,
        'memberCount': info.householdSize,
        'headUser': {
          'firstName': info.firstName,
          'middleName': info.middleName,
          'lastName': info.lastName,
          'phoneNumber': info.phone,
        },
      },
      coverage: null,
      card: null,
      eligibility: null,
      viewer: null,
      claims: const [],
      payments: const [],
      notifications: const [
        {
          'id': 'offline-sync-1',
          'type': 'SYSTEM_ALERT',
          'title': 'Sync Required',
          'body': 'Your registration is saved offline. Open the app when online to sync your account.',
          'isRead': false,
          'createdAt': '',
        }
      ],
      digitalCards: const [],
      referrals: const [],
      familyMembers: const [],
      syncedAt: '',
    );
  }

  void reset() {
    emit(const RegistrationState());
    _clearDraft();
  }

  // ── Draft persistence ──────────────────────────────────────────────────────

  Future<void> _saveDraft(RegistrationState s) async {
    try {
      // Only persist steps that have meaningful data to restore
      if (s.currentStep == RegistrationStep.start ||
          s.currentStep == RegistrationStep.completed ||
          s.currentStep == RegistrationStep.setupAccount) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'step': s.currentStep.name,
        if (s.personalInfo != null) 'personalInfo': s.personalInfo!.toJson(),
        if (s.identity != null) 'identity': s.identity!.toJson(),
        if (s.membership != null) 'membership': s.membership!.toJson(),
      };
      await prefs.setString(_kDraftKey, jsonEncode(payload));
    } catch (_) {
      // Draft save is best-effort — never crash the app
    }
  }

  Future<RegistrationState?> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDraftKey);
      if (raw == null || raw.isEmpty) return null;
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();

      final stepName = json['step']?.toString() ?? '';
      final step = RegistrationStep.values.firstWhere(
        (e) => e.name == stepName,
        orElse: () => RegistrationStep.personalInfo,
      );

      PersonalInfoModel? personalInfo;
      if (json['personalInfo'] != null) {
        personalInfo = PersonalInfoModel.fromJson(
          (json['personalInfo'] as Map).cast<String, dynamic>(),
        );
      }

      IdentityModel? identity;
      if (json['identity'] != null) {
        identity = IdentityModel.fromJson(
          (json['identity'] as Map).cast<String, dynamic>(),
        );
      }

      MembershipSelection? membership;
      if (json['membership'] != null) {
        membership = MembershipSelection.fromJson(
          (json['membership'] as Map).cast<String, dynamic>(),
        );
      }

      return RegistrationState(
        currentStep: step,
        personalInfo: personalInfo,
        identity: identity,
        membership: membership,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDraftKey);
    } catch (_) {}
  }
}
