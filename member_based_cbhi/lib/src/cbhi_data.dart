import 'dart:convert';
import 'dart:io' if (dart.library.html) 'shared/web_stubs.dart';


import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' if (dart.library.html) 'shared/db_stubs.dart';

import 'registration/models/identity_model.dart';
import 'registration/models/membership_type.dart';
import 'registration/models/personal_info_model.dart';
import 'shared/local_attachment_store.dart';
import 'shared/secure_storage_service.dart';

/// Converts a value that may be num, String, or null to double.
/// Postgres numeric columns are returned as strings over JSON.
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String get kDefaultApiBaseUrl {
  const envUrl = String.fromEnvironment('CBHI_API_BASE_URL');
  // Normalize: strip trailing slash, ensure /api/v1 suffix
  var url = envUrl.isNotEmpty ? envUrl : 'https://maya-u8mf.onrender.com/api/v1';
  url = url.trimRight();
  if (url.endsWith('/')) url = url.substring(0, url.length - 1);
  if (!url.endsWith('/api/v1')) url = '$url/api/v1';
  return url;
}

@immutable
class AppUserProfile {
  const AppUserProfile({
    required this.id,
    required this.displayName,
    this.firstName,
    this.middleName,
    this.lastName,
    this.phoneNumber,
    this.email,
    this.role,
    this.preferredLanguage,
    this.householdCode,
    this.beneficiaryId,
    this.membershipId,
    this.lastLoginAt,
  });

  final String id;
  final String displayName;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? phoneNumber;
  final String? email;
  final String? role;
  final String? preferredLanguage;
  final String? householdCode;
  final String? beneficiaryId;
  final String? membershipId;
  final String? lastLoginAt;

  factory AppUserProfile.fromJson(Map<String, dynamic> json) {
    return AppUserProfile(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Member',
      firstName: json['firstName']?.toString(),
      middleName: json['middleName']?.toString(),
      lastName: json['lastName']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString(),
      preferredLanguage: json['preferredLanguage']?.toString(),
      householdCode: json['householdCode']?.toString(),
      beneficiaryId: json['beneficiaryId']?.toString(),
      membershipId: json['membershipId']?.toString(),
      lastLoginAt: json['lastLoginAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'firstName': firstName,
    'middleName': middleName,
    'lastName': lastName,
    'phoneNumber': phoneNumber,
    'email': email,
    'role': role,
    'preferredLanguage': preferredLanguage,
    'householdCode': householdCode,
    'beneficiaryId': beneficiaryId,
    'membershipId': membershipId,
    'lastLoginAt': lastLoginAt,
  };
}

@immutable
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    required this.user,
    this.refreshToken,
    this.refreshTokenExpiresAt,
  });

  final String accessToken;
  final String tokenType;
  final String expiresAt;
  final AppUserProfile user;
  final String? refreshToken;
  final String? refreshTokenExpiresAt;

  bool get isExpired {
    final exp = DateTime.tryParse(expiresAt);
    if (exp == null) return false;
    return DateTime.now().isAfter(exp.subtract(const Duration(minutes: 5)));
  }

  bool get refreshTokenExpired {
    final exp = DateTime.tryParse(refreshTokenExpiresAt ?? '');
    if (exp == null) return true;
    return DateTime.now().isAfter(exp);
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken']?.toString() ?? '',
      tokenType: json['tokenType']?.toString() ?? 'Bearer',
      expiresAt: json['expiresAt']?.toString() ?? '',
      user: AppUserProfile.fromJson(
        (json['user'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      refreshToken: json['refreshToken']?.toString(),
      refreshTokenExpiresAt: json['refreshTokenExpiresAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'tokenType': tokenType,
    'expiresAt': expiresAt,
    'user': user.toJson(),
    'refreshToken': refreshToken,
    'refreshTokenExpiresAt': refreshTokenExpiresAt,
  };
}

@immutable
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.membershipId,
    required this.fullName,
    required this.coverageStatus,
    required this.isPrimaryHolder,
    required this.isEligible,
    this.gender,
    this.dateOfBirth,
    this.relationshipToHouseholdHead,
    this.identityType,
    this.identityNumber,
    this.birthCertificateRef,
    this.birthCertificatePath,
    this.idDocumentPath,
    this.photoPath,
    this.phoneNumber,
    this.canLoginIndependently = false,
  });

  final String id;
  final String membershipId;
  final String fullName;
  final String coverageStatus;
  final bool isPrimaryHolder;
  final bool isEligible;
  final String? gender;
  final String? dateOfBirth;
  final String? relationshipToHouseholdHead;
  final String? identityType;
  final String? identityNumber;
  final String? birthCertificateRef;
  final String? birthCertificatePath;
  final String? idDocumentPath;
  final String? photoPath;
  final String? phoneNumber;
  final bool canLoginIndependently;

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id']?.toString() ?? '',
      membershipId: json['membershipId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Member',
      coverageStatus: json['coverageStatus']?.toString() ?? 'UNKNOWN',
      isPrimaryHolder: json['isPrimaryHolder'] == true,
      isEligible: json['isEligible'] != false,
      gender: json['gender']?.toString(),
      dateOfBirth: json['dateOfBirth']?.toString(),
      relationshipToHouseholdHead: json['relationshipToHouseholdHead']
          ?.toString(),
      identityType: json['identityType']?.toString(),
      identityNumber: json['identityNumber']?.toString(),
      birthCertificateRef: json['birthCertificateRef']?.toString(),
      birthCertificatePath: json['birthCertificatePath']?.toString(),
      idDocumentPath: json['idDocumentPath']?.toString(),
      photoPath: json['photoPath']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      canLoginIndependently: json['canLoginIndependently'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'membershipId': membershipId,
    'fullName': fullName,
    'coverageStatus': coverageStatus,
    'isPrimaryHolder': isPrimaryHolder,
    'isEligible': isEligible,
    'gender': gender,
    'dateOfBirth': dateOfBirth,
    'relationshipToHouseholdHead': relationshipToHouseholdHead,
    'identityType': identityType,
    'identityNumber': identityNumber,
    'birthCertificateRef': birthCertificateRef,
    'birthCertificatePath': birthCertificatePath,
    'idDocumentPath': idDocumentPath,
    'photoPath': photoPath,
    'phoneNumber': phoneNumber,
    'canLoginIndependently': canLoginIndependently,
  };
}

@immutable
class FamilyMemberDraft {
  const FamilyMemberDraft({
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    required this.relationshipToHouseholdHead,
    this.identityType,
    this.identityNumber,
    this.phoneNumber,
    this.photoPath,
    this.birthCertificateRef,
    this.birthCertificatePath,
    this.idDocumentPath,
  });

  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;
  final DateTime dateOfBirth;
  final String relationshipToHouseholdHead;
  final String? identityType;
  final String? identityNumber;
  final String? phoneNumber;
  final String? photoPath;
  final String? birthCertificateRef;
  final String? birthCertificatePath;
  final String? idDocumentPath;

  String get fullName => [
    firstName,
    middleName,
    lastName,
  ].where((value) => value != null && value.trim().isNotEmpty).join(' ');

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'middleName': middleName,
    'lastName': lastName,
    'gender': gender,
    'dateOfBirth': DateFormat('yyyy-MM-dd').format(dateOfBirth),
    'relationshipToHouseholdHead': relationshipToHouseholdHead,
    'identityType': identityType,
    'identityNumber': identityNumber,
    'phoneNumber': phoneNumber,
    'beneficiaryPhotoPath': photoPath,
    'birthCertificateRef': birthCertificateRef,
    'birthCertificatePath': birthCertificatePath,
    'idDocumentPath': idDocumentPath,
  };
}

@immutable
class CbhiSnapshot {
  const CbhiSnapshot({
    required this.household,
    required this.claims,
    required this.payments,
    required this.notifications,
    required this.digitalCards,
    required this.referrals,
    required this.familyMembers,
    required this.syncedAt,
    this.coverage,
    this.card,
    this.eligibility,
    this.viewer,
  });

  final Map<String, dynamic> household;
  final Map<String, dynamic>? coverage;
  final Map<String, dynamic>? card;
  final Map<String, dynamic>? eligibility;
  final Map<String, dynamic>? viewer;
  final List<Map<String, dynamic>> claims;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> notifications;
  final List<Map<String, dynamic>> digitalCards;
  final List<Map<String, dynamic>> referrals;
  final List<FamilyMember> familyMembers;
  final String syncedAt;

  String get householdCode => household['householdCode']?.toString() ?? '';

  String get headName {
    final headUser =
        (household['headUser'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = [
      headUser['firstName'],
      headUser['middleName'],
      headUser['lastName'],
    ].where((value) => value != null && value.toString().isNotEmpty).join(' ');
    return name.isEmpty ? 'Member' : name;
  }

  String get viewerName => viewer?['fullName']?.toString() ?? headName;

  String get viewerRole => viewer?['role']?.toString() ?? '';

  String get viewerMembershipId => viewer?['membershipId']?.toString() ?? '';

  String get viewerBeneficiaryId => viewer?['beneficiaryId']?.toString() ?? '';

  String? get viewerPhotoPath => viewer?['photoPath']?.toString();

  String get coverageStatus =>
      coverage?['status']?.toString() ??
      household['coverageStatus']?.toString() ??
      'UNKNOWN';

  double get premiumAmount =>
      _toDouble(coverage?['premiumAmount']);

  double get paidAmount => _toDouble(coverage?['paidAmount']);

  String get coverageNumber => coverage?['coverageNumber']?.toString() ?? '';

  String get cardToken =>
      (card?['token'] ?? card?['accessToken'])?.toString() ?? '';

  Map<String, dynamic>? get currentDigitalCard {
    if (digitalCards.isEmpty) {
      return null;
    }
    final beneficiaryId = viewerBeneficiaryId;
    if (beneficiaryId.isEmpty) {
      return digitalCards.first;
    }
    final match = digitalCards.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['memberId']?.toString() == beneficiaryId,
      orElse: () => null,
    );
    return match;
  }

  FamilyMember? get currentMember {
    if (familyMembers.isEmpty) {
      return null;
    }
    final beneficiaryId = viewerBeneficiaryId;
    if (beneficiaryId.isEmpty) {
      return familyMembers.first;
    }
    for (final member in familyMembers) {
      if (member.id == beneficiaryId) {
        return member;
      }
    }
    return familyMembers.first;
  }

  bool get hasLiveCard => cardToken.isNotEmpty;

  bool get isPendingSync => householdCode.startsWith('LOCAL-') || !hasLiveCard;

  factory CbhiSnapshot.empty() {
    return const CbhiSnapshot(
      household: <String, dynamic>{},
      coverage: null,
      card: null,
      eligibility: null,
      viewer: null,
      claims: <Map<String, dynamic>>[],
      payments: <Map<String, dynamic>>[],
      notifications: <Map<String, dynamic>>[],
      digitalCards: <Map<String, dynamic>>[],
      referrals: <Map<String, dynamic>>[],
      familyMembers: <FamilyMember>[],
      syncedAt: '',
    );
  }

  factory CbhiSnapshot.fromJson(Map<String, dynamic> json) {
    return CbhiSnapshot(
      household: (json['household'] as Map? ?? const {})
          .cast<String, dynamic>(),
      coverage: json['coverage'] == null
          ? null
          : (json['coverage'] as Map).cast<String, dynamic>(),
      card: json['card'] == null
          ? null
          : (json['card'] as Map).cast<String, dynamic>(),
      eligibility: json['eligibility'] == null
          ? null
          : (json['eligibility'] as Map).cast<String, dynamic>(),
      viewer: json['viewer'] == null
          ? null
          : (json['viewer'] as Map).cast<String, dynamic>(),
      claims: (json['claims'] as List? ?? const [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList(growable: false),
      payments: (json['payments'] as List? ?? const [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList(growable: false),
      notifications: (json['notifications'] as List? ?? const [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList(growable: false),
      digitalCards: (json['digitalCards'] as List? ?? const [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList(growable: false),
      referrals: (json['referrals'] as List? ?? const [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList(growable: false),
      familyMembers: (json['familyMembers'] as List? ?? const [])
          .map(
            (item) =>
                FamilyMember.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList(growable: false),
      syncedAt: json['syncedAt']?.toString() ?? '',
    );
  }

  CbhiSnapshot copyWith({
    Map<String, dynamic>? household,
    Map<String, dynamic>? coverage,
    Map<String, dynamic>? card,
    Map<String, dynamic>? eligibility,
    Map<String, dynamic>? viewer,
    List<Map<String, dynamic>>? claims,
    List<Map<String, dynamic>>? payments,
    List<Map<String, dynamic>>? notifications,
    List<Map<String, dynamic>>? digitalCards,
    List<Map<String, dynamic>>? referrals,
    List<FamilyMember>? familyMembers,
    String? syncedAt,
  }) {
    return CbhiSnapshot(
      household: household ?? this.household,
      coverage: coverage ?? this.coverage,
      card: card ?? this.card,
      eligibility: eligibility ?? this.eligibility,
      viewer: viewer ?? this.viewer,
      claims: claims ?? this.claims,
      payments: payments ?? this.payments,
      notifications: notifications ?? this.notifications,
      digitalCards: digitalCards ?? this.digitalCards,
      referrals: referrals ?? this.referrals,
      familyMembers: familyMembers ?? this.familyMembers,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'household': household,
    'coverage': coverage,
    'card': card,
    'eligibility': eligibility,
    'viewer': viewer,
    'claims': claims,
    'payments': payments,
    'notifications': notifications,
    'digitalCards': digitalCards,
    'referrals': referrals,
    'familyMembers': familyMembers.map((member) => member.toJson()).toList(),
    'syncedAt': syncedAt,
  };
}

class CbhiLocalDb {
  CbhiLocalDb._();

  static final CbhiLocalDb instance = CbhiLocalDb._();

  Database? _database;
  // Web fallback: SharedPreferences-based storage (no WASM needed)
  SharedPreferences? _webPrefs;

  Future<void> init() async {
    if (_database != null || _webPrefs != null) return;

    if (kIsWeb) {
      // On web, use SharedPreferences instead of SQLite to avoid
      // the WASM worker requirement of sqflite_common_ffi_web.
      _webPrefs = await SharedPreferences.getInstance();
      return;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = p.join(await getDatabasesPath(), 'cbhi_local.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE snapshot_cache (
            cache_key TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_actions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            payload TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Database get _db {
    final db = _database;
    if (db == null) throw StateError('Database not initialized');
    return db;
  }

  // ── Web SharedPreferences helpers ─────────────────────────────────────────

  static const _snapshotPrefix = 'cbhi_snapshot_';
  static const _pendingActionsKey = 'cbhi_pending_actions';

  Future<CbhiSnapshot?> readSnapshot([String cacheKey = 'active']) async {
    if (kIsWeb) {
      final raw = _webPrefs!.getString('$_snapshotPrefix$cacheKey');
      if (raw == null || raw.isEmpty) return null;
      try {
        return CbhiSnapshot.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>(),
        );
      } catch (_) {
        return null;
      }
    }
    final rows = await _db.query(
      'snapshot_cache',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CbhiSnapshot.fromJson(
      (jsonDecode(rows.first['payload'] as String) as Map)
          .cast<String, dynamic>(),
    );
  }

  Future<void> writeSnapshot(
    CbhiSnapshot snapshot, [
    String cacheKey = 'active',
  ]) async {
    if (kIsWeb) {
      await _webPrefs!.setString(
        '$_snapshotPrefix$cacheKey',
        jsonEncode(snapshot.toJson()),
      );
      return;
    }
    await _db.insert('snapshot_cache', {
      'cache_key': cacheKey,
      'payload': jsonEncode(snapshot.toJson()),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> queueAction(String type, Map<String, dynamic> payload) async {
    if (kIsWeb) {
      final raw = _webPrefs!.getString(_pendingActionsKey) ?? '[]';
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final id = DateTime.now().millisecondsSinceEpoch;
      list.add({
        'id': id,
        'type': type,
        'payload': jsonEncode(payload),
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _webPrefs!.setString(_pendingActionsKey, jsonEncode(list));
      return id;
    }
    return _db.insert('pending_actions', {
      'type': type,
      'payload': jsonEncode(payload),
      'retry_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> incrementRetryCount(int id) async {
    if (kIsWeb) {
      final raw = _webPrefs!.getString(_pendingActionsKey) ?? '[]';
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      for (final item in list) {
        if (item['id'] == id) {
          item['retry_count'] = (item['retry_count'] as int? ?? 0) + 1;
        }
      }
      await _webPrefs!.setString(_pendingActionsKey, jsonEncode(list));
      return;
    }
    await _db.rawUpdate(
      'UPDATE pending_actions SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  Future<List<Map<String, Object?>>> readPendingActionRows() async {
    if (kIsWeb) {
      final raw = _webPrefs!.getString(_pendingActionsKey) ?? '[]';
      return (jsonDecode(raw) as List).cast<Map<String, Object?>>();
    }
    return _db.query('pending_actions', orderBy: 'id ASC');
  }

  Future<void> removeAction(int id) async {
    if (kIsWeb) {
      final raw = _webPrefs!.getString(_pendingActionsKey) ?? '[]';
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .where((item) => item['id'] != id)
          .toList();
      await _webPrefs!.setString(_pendingActionsKey, jsonEncode(list));
      return;
    }
    await _db.delete('pending_actions', where: 'id = ?', whereArgs: [id]);
  }
}

class _ApiException implements Exception {
  const _ApiException(this.message, {this.retryable = false, this.statusCode});

  final String message;
  final bool retryable;
  final int? statusCode;

  @override
  String toString() => message;
}

class CbhiRepository {
  CbhiRepository({
    required this.localDb,
    SharedPreferences? prefs,
    http.Client? client,
    String? apiBaseUrl,
  }) : _client = client ?? http.Client(),
       apiBaseUrl = apiBaseUrl ?? kDefaultApiBaseUrl;

  final CbhiLocalDb localDb;
  final http.Client _client;
  final String apiBaseUrl;

  static const _sessionStorageKey = 'cbhi_auth_session';

  Future<void> _persistSession(AuthSession session) async {
    await SecureStorageService.instance.write(
      _sessionStorageKey,
      jsonEncode(session.toJson()),
    );
  }

  Future<AuthSession?> _readStoredSession() async {
    final raw = await SecureStorageService.instance.read(_sessionStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AuthSession.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Get the current access token — used to pass auth to PaymentScreen during registration
  Future<String?> getCurrentAccessToken() async {
    final session = await _readStoredSession();
    return session?.accessToken;
  }

  static Future<CbhiRepository> create({
    String? apiBaseUrl,
  }) async {
    final db = CbhiLocalDb.instance;
    await db.init();
    return CbhiRepository(
      localDb: db,
      apiBaseUrl: apiBaseUrl,
    );
  }

  Future<CbhiSnapshot> loadCachedSnapshot() async {
    return (await localDb.readSnapshot()) ?? CbhiSnapshot.empty();
  }

  Future<AuthSession?> restoreSession() async {
    final session = await _readStoredSession();
    if (session == null) return null;

    // If access token is still valid, refresh the profile
    if (!session.isExpired) {
      try {
        final profileJson = await _getJson(
          '/auth/me',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
        );
        final refreshed = AuthSession(
          accessToken: session.accessToken,
          tokenType: session.tokenType,
          expiresAt: session.expiresAt,
          user: AppUserProfile.fromJson(profileJson),
          refreshToken: session.refreshToken,
          refreshTokenExpiresAt: session.refreshTokenExpiresAt,
        );
        await _persistSession(refreshed);
        return refreshed;
      } on _ApiException catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403) {
          // Try refresh token before giving up
          return _tryRefreshToken(session);
        }
        return session;
      } catch (_) {
        return session;
      }
    }

    // Access token expired — try refresh token
    return _tryRefreshToken(session);
  }

  Future<AuthSession?> _tryRefreshToken(AuthSession session) async {
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await logout();
      return null;
    }

    if (session.refreshTokenExpired) {
      await logout();
      return null;
    }

    try {
      final response = await _postJson('/auth/refresh', {
        'refreshToken': refreshToken,
      });
      final newSession = AuthSession.fromJson(response);
      await _persistSession(newSession);
      return newSession;
    } catch (_) {
      await logout();
      return null;
    }
  }

  Future<AuthSession?> currentSession() => restoreSession();

  /// Restore session from a known access token (used by biometric login)
  Future<AuthSession?> restoreSessionFromToken(String accessToken) async {
    try {
      final profileJson = await _getJson(
        '/auth/me',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      final session = AuthSession(
        accessToken: accessToken,
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        user: AppUserProfile.fromJson(profileJson),
      );
      await _persistSession(session);
      return session;
    } catch (_) {
      return null;
    }
  }

  /// Real-time check: is this phone number already registered?
  /// Returns null if available, or an error message string if taken.
  Future<String?> checkPhoneAvailability(String phone) async {
    try {
      final encoded = Uri.encodeComponent(phone.trim());
      final result = await _getJson('/cbhi/registration/check-phone/$encoded');
      final available = result['available'] == true;
      return available ? null : (result['message']?.toString() ?? 'Phone number already registered.');
    } catch (_) {
      return null; // Don't block registration on check failure
    }
  }

  /// Real-time check: is this ID number already registered?
  /// Returns null if available, or an error message string if taken.
  Future<String?> checkIdAvailability(String idNumber) async {
    try {
      final encoded = Uri.encodeComponent(idNumber.trim());
      final result = await _getJson('/cbhi/registration/check-id/$encoded');
      final available = result['available'] == true;
      return available ? null : (result['message']?.toString() ?? 'ID number already registered.');
    } catch (_) {
      return null;
    }
  }

  Future<AuthSession> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    final response = await _postJson('/auth/login', {
      'identifier': identifier,
      'password': password,
    });
    final session = AuthSession.fromJson(response);
    await _persistSession(session);
    return session;
  }

  Future<AuthSession> loginFamilyMemberWithPassword({
    required String phoneNumber,
    String? membershipId,
    String? householdCode,
    String? fullName,
    required String password,
  }) async {
    final response = await _postJson('/auth/family/login', {
      'phoneNumber': phoneNumber,
      'membershipId': membershipId,
      'householdCode': householdCode,
      'fullName': fullName,
      'password': password,
    });
    final session = AuthSession.fromJson(response);
    await _persistSession(session);
    return session;
  }

  Future<void> logout() async {
    await SecureStorageService.instance.delete(_sessionStorageKey);
  }

  Future<CbhiSnapshot> registerFull({
    required PersonalInfoModel personalInfo,
    required IdentityModel identity,
    required MembershipSelection membership,
    List<String> indigentProofPaths = const [],
  }) async {
    final stepOnePayload = await _buildRegistrationStepOnePayload(personalInfo);
    final indigentProofUploads =
        await _buildIndigentProofUploads(indigentProofPaths);
    final stepTwoPayload = {
      'identityType': identity.identityType,
      'identityNumber': identity.identityNumber,
      'membershipType': membership.membershipType.value,
      'premiumAmount': membership.premiumAmount,
      'eligibilitySignals': {
        'employmentStatus': identity.employmentStatusForApi,
      },
      'indigentProofUploads': indigentProofUploads,
    };
    final fullPayload = {
      'personalInfo': personalInfo.toJson(),
      'identity': identity.toJson(),
      'membership': membership.toJson(),
      'indigentProofPaths': indigentProofPaths,
      'stepOnePayload': stepOnePayload,
      'stepTwoPayload': stepTwoPayload,
    };

    try {
      return await _registerFullRemote(
        personalInfo: personalInfo,
        identity: identity,
        membership: membership,
        indigentProofPaths: indigentProofPaths,
      );
    } on _ApiException catch (error) {
      if (!error.retryable) {
        rethrow; // surface validation / auth errors to the user
      }
      // Retryable (5xx / network) — queue offline and return pending snapshot
      // so the user can still see their data while we retry in the background
      await localDb.queueAction('registration_full', fullPayload);
      final snapshot = _buildPendingSnapshot(
        personalInfo: personalInfo,
        membership: membership,
      );
      await localDb.writeSnapshot(snapshot);
      return snapshot;
    }
  }

  Future<List<FamilyMember>> fetchMyFamily() async {
    final response = await _getJson('/cbhi/family', authorized: true);
    return _applyFamilyPayload(response);
  }

  Future<({List<FamilyMember> members, String? setupCode})> addFamilyMember(FamilyMemberDraft draft) async {
    final payload = await _buildFamilyMemberPayload(draft);
    final response = await _postJson('/cbhi/family', payload, authorized: true);
    final members = await _applyFamilyPayload(response);
    final setupCode = response['setupCode']?.toString();
    return (members: members, setupCode: setupCode);
  }

  Future<List<FamilyMember>> updateFamilyMember(
    String memberId,
    FamilyMemberDraft draft,
  ) async {
    final payload = await _buildFamilyMemberPayload(draft);
    final response = await _patchJson(
      '/cbhi/family/$memberId',
      payload,
      authorized: true,
    );
    return _applyFamilyPayload(response);
  }

  Future<List<FamilyMember>> removeFamilyMember(String memberId) async {
    final response = await _deleteJson(
      '/cbhi/family/$memberId',
      authorized: true,
    );
    return _applyFamilyPayload(response);
  }

  /// Set the initial password after account setup (called from AccountSetupScreen).
  /// Requires an active authenticated session.
  Future<void> setInitialPassword({required String password}) async {
    await _postJson('/auth/set-password', {'password': password}, authorized: true);
  }

  /// Set the initial password for first-time setup WITHOUT invalidating the
  /// current session. Use this when the user is setting a password for the
  /// first time after registration — the session must stay active.
  /// Set the initial password for first-time setup. If [setupCode] is provided,
  /// it uses that as an implicit credential (allowing setup without a session).
  Future<void> setInitialPasswordDirect({required String password, String? setupCode, String? phone}) async {
    await _postJson('/auth/set-initial-password', {
      'password': password,
      if (setupCode != null) 'setupCode': setupCode,
      if (phone != null) 'phone': phone,
    }, authorized: setupCode == null && phone == null);
  }

  /// GDPR: anonymise and deactivate the account.
  Future<void> deleteAccount() async {
    await _postJson('/auth/delete-account', const <String, dynamic>{}, authorized: true);
    await logout();
  }

  Future<CbhiSnapshot> renewCoverage({
    String? paymentMethod,
    String? providerName,
    String? receiptNumber,
  }) async {
    final response = await _postJson('/cbhi/coverage/renew', {
      'paymentMethod': paymentMethod,
      'providerName': providerName,
      'receiptNumber': receiptNumber,
    }, authorized: true);
    final snapshot = _snapshotFromRemote(response);
    await localDb.writeSnapshot(snapshot);
    return snapshot;
  }

  Future<List<Map<String, dynamic>>> markNotificationRead(
    String notificationId,
  ) async {
    final response = await _postJson(
      '/cbhi/notifications/$notificationId/read',
      const <String, dynamic>{},
      authorized: true,
    );
    final notifications = (response['notifications'] as List? ?? const [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList(growable: false);
    final snapshot = await loadCachedSnapshot();
    await localDb.writeSnapshot(
      snapshot.copyWith(
        notifications: notifications,
        syncedAt:
            response['syncedAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
    );
    return notifications;
  }

  /// Validate an ID document image using Google Vision API (server-side)
  Future<Map<String, dynamic>> validateIdDocument({
    required String imageBase64,
    String? expectedIdNumber,
  }) async {
    return _postJson('/vision/validate-id', {
      'imageBase64': imageBase64,
      'expectedIdNumber': expectedIdNumber,
    });
  }

  /// Validate an indigent supporting document using Google Vision API
  Future<Map<String, dynamic>> validateIndigentDocument({
    required String imageBase64,
  }) async {
    return _postJson('/vision/validate-indigent-doc', {
      'imageBase64': imageBase64,
    });
  }

  /// Submit an indigent application with document metadata
  Future<Map<String, dynamic>> submitIndigentApplication({
    required String userId,
    required int income,
    required String employmentStatus,
    required int familySize,
    required bool hasProperty,
    required bool disabilityStatus,
    required List<String> documents,
    List<Map<String, dynamic>>? documentMeta,
  }) async {
    final payload = {
      'userId': userId,
      'income': income,
      'employmentStatus': employmentStatus,
      'familySize': familySize,
      'hasProperty': hasProperty,
      'disabilityStatus': disabilityStatus,
      'documents': documents,
      'documentMeta': documentMeta,
    };

    try {
      return await _postJson('/indigent/apply', payload, authorized: true);
    } on _ApiException catch (e) {
      if (!e.retryable) rethrow;
      await localDb.queueAction('submit_indigent_application', payload);
      return {
        'status': 'queued',
        'message': 'Application queued for sync due to network connectivity.'
      };
    }
  }

  /// Get document requirements for indigent applications
  Future<Map<String, dynamic>> getIndigentDocumentRequirements() async {
    return _getJson('/indigent/document-requirements');
  }

  /// Get all indigent applications for the current user
  Future<List<Map<String, dynamic>>> getMyIndigentApplications() async {
    final response = await _getJson('/indigent/my/applications', authorized: true);
    return (response as List? ?? [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }

  /// Initiate a Chapa payment for CBHI premium renewal
  Future<Map<String, dynamic>> initiatePayment({
    required double amount,
    String? description,
    String? accessToken,
  }) async {
    if (accessToken != null && accessToken.isNotEmpty) {
      // Use provided token directly (e.g. from registration response)
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      try {
        final response = await _client
            .post(
              Uri.parse('$apiBaseUrl/payments/initiate'),
              headers: headers,
              body: jsonEncode({
                'amount': amount,
                'description': description,
              }),
            )
            .timeout(_kWriteTimeout);
        return _decodeResponse('/payments/initiate', response);
      } catch (error) {
        if (error is _ApiException) rethrow;
        throw const _ApiException(
          'Connection to server failed. Please check your internet or the server status.',
          retryable: true,
        );
      }
    }
    return _postJson('/payments/initiate', {
      'amount': amount,
      'description': description,
    }, authorized: true);
  }

  /// Verify a Chapa payment by transaction reference
  Future<Map<String, dynamic>> verifyPayment(String txRef) async {
    return _getJson('/payments/verify/$txRef', authorized: true);
  }

  /// Search accredited health facilities
  Future<List<Map<String, dynamic>>> searchFacilities({String? query}) async {
    final q = query?.trim() ?? '';
    final path = q.isEmpty
        ? '/facilities'
        : '/facilities?q=${Uri.encodeComponent(q)}';
    final response = await _getJson(path);
    return (response['facilities'] as List? ?? [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }



  Future<CbhiSnapshot> sync([String? householdCode]) async {
    await syncPendingActions();
    final session = await restoreSession();
    if (session != null) {
      try {
        final remote = await _getJson('/cbhi/me', authorized: true);
        final snapshot = _snapshotFromRemote(remote);
        await localDb.writeSnapshot(snapshot);
        return snapshot;
      } on _ApiException catch (error) {
        // 401 with a pending-sync token is expected — fall back to cached data
        if (!error.retryable && error.statusCode != 401) {
          rethrow;
        }
      }
    }
    return loadCachedSnapshot();
  }

  Future<void> syncPendingActions() async {
    final rows = await localDb.readPendingActionRows();
    for (final row in rows) {
      final id = row['id'] as int;
      final type = row['type'] as String;
      final retryCount = (row['retry_count'] as int?) ?? 0;
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;

      // Dead-letter: skip permanently failed actions (>= 5 attempts)
      if (retryCount >= 5) {
        await localDb.removeAction(id);
        continue;
      }

      try {
        if (type == 'registration_full') {
          final stepOnePayload = (payload['stepOnePayload'] as Map?)
              ?.cast<String, dynamic>();
          final stepTwoPayload = (payload['stepTwoPayload'] as Map?)
              ?.cast<String, dynamic>();
          if (stepOnePayload != null && stepTwoPayload != null) {
            final stepOneResponse = await _postJson(
              '/cbhi/registration/step-1',
              stepOnePayload,
            );
            final registrationId =
                stepOneResponse['registrationId']?.toString() ?? '';
            if (registrationId.isEmpty) {
              throw const _ApiException(
                'Registration step 1 did not return an id.',
              );
            }
            final response = await _postJson('/cbhi/registration/step-2', {
              ...stepTwoPayload,
              'registrationId': registrationId,
            });
            final snapshot = _snapshotFromRegistration(response);
            await _storeAuthIfPresent(response);
            await localDb.writeSnapshot(snapshot);
          } else {
            final proofRaw = payload['indigentProofPaths'];
            final proofPaths = proofRaw is List
                ? proofRaw.map((e) => e.toString()).toList()
                : const <String>[];
            await _registerFullRemote(
              personalInfo: PersonalInfoModel.fromJson(
                (payload['personalInfo'] as Map).cast<String, dynamic>(),
              ),
              identity: IdentityModel.fromJson(
                (payload['identity'] as Map).cast<String, dynamic>(),
              ),
              membership: MembershipSelection.fromJson(
                (payload['membership'] as Map).cast<String, dynamic>(),
              ),
              indigentProofPaths: proofPaths,
            );
          }
        } else if (type == 'registration_step_two') {
          final response = await _postJson(
            '/cbhi/registration/step-2',
            payload,
          );
          final snapshot = _snapshotFromRegistration(response);
          await _storeAuthIfPresent(response);
          await localDb.writeSnapshot(snapshot);
        } else if (type == 'submit_indigent_application') {
          await _postJson('/indigent/apply', payload, authorized: true);
        }
        await localDb.removeAction(id);
      } catch (error) {
        if (error is _ApiException && !error.retryable) {
          // Permanent failure — remove immediately
          await localDb.removeAction(id);
          continue;
        }
        // Transient failure — increment retry count and continue to next action
        await localDb.incrementRetryCount(id);
      }
    }
  }

  Future<CbhiSnapshot> _registerFullRemote({
    required PersonalInfoModel personalInfo,
    required IdentityModel identity,
    required MembershipSelection membership,
    List<String> indigentProofPaths = const [],
  }) async {
    final stepOnePayload = await _buildRegistrationStepOnePayload(personalInfo);
    final stepOneResponse = await _postJson(
      '/cbhi/registration/step-1',
      stepOnePayload,
    );

    final registrationId = stepOneResponse['registrationId']?.toString() ?? '';
    if (registrationId.isEmpty) {
      throw const _ApiException('Registration step 1 did not return an id.');
    }

    final indigentProofUploads =
        await _buildIndigentProofUploads(indigentProofPaths);
    final stepTwoPayload = {
      'registrationId': registrationId,
      'identityType': identity.identityType,
      'identityNumber': identity.identityNumber,
      'membershipType': membership.membershipType.value,
      'premiumAmount': membership.premiumAmount,
      'eligibilitySignals': {
        'employmentStatus': identity.employmentStatusForApi,
      },
      'indigentProofUploads': indigentProofUploads,
      'idFrontUpload': await _buildAttachmentPayload(identity.idFrontPath),
      'idBackUpload': await _buildAttachmentPayload(identity.idBackPath),
      if (identity.verificationId != null) 'verificationId': identity.verificationId,
      if (identity.verificationStatus != null) 'verificationStatus': identity.verificationStatus,
    };

    try {
      final stepTwoResponse = await _postJson(
        '/cbhi/registration/step-2',
        stepTwoPayload,
      );
      await _storeAuthIfPresent(stepTwoResponse);
      final snapshot = _snapshotFromRegistration(stepTwoResponse);
      await localDb.writeSnapshot(snapshot);
      return snapshot;
    } on _ApiException catch (error) {
      if (!error.retryable) {
        rethrow;
      }

      await localDb.queueAction('registration_step_two', stepTwoPayload);
      final snapshot = _buildPendingSnapshot(
        personalInfo: personalInfo,
        membership: membership,
        householdCode: stepOneResponse['householdCode']?.toString(),
      );
      await localDb.writeSnapshot(snapshot);
      return snapshot;
    }
  }


  Future<void> _storeAuthIfPresent(Map<String, dynamic> json) async {
    final auth = json['auth'];
    if (auth is Map) {
      await _persistSession(AuthSession.fromJson(auth.cast<String, dynamic>()));
    }
  }

  Future<Map<String, dynamic>> _buildRegistrationStepOnePayload(
    PersonalInfoModel personalInfo,
  ) async {
    return {
      ...personalInfo.toJson(),
      'beneficiaryPhotoUpload': await _buildAttachmentPayload(
        personalInfo.photoPath,
      ),
      'birthCertificateUpload': await _buildAttachmentPayload(
        personalInfo.birthCertificatePath,
      ),
      'idDocumentUpload': await _buildAttachmentPayload(
        personalInfo.idDocumentPath,
      ),
    };
  }

  Future<Map<String, dynamic>> _buildFamilyMemberPayload(
    FamilyMemberDraft draft,
  ) async {
    return {
      ...draft.toJson(),
      'beneficiaryPhotoUpload': await _buildAttachmentPayload(draft.photoPath),
      'birthCertificateUpload': await _buildAttachmentPayload(
        draft.birthCertificatePath,
      ),
      'idDocumentUpload': await _buildAttachmentPayload(draft.idDocumentPath),
    };
  }

  Future<List<Map<String, dynamic>>?> _buildIndigentProofUploads(
    List<String> paths,
  ) async {
    if (paths.isEmpty) return null;
    final out = <Map<String, dynamic>>[];
    for (final path in paths) {
      final one = await _buildAttachmentPayload(path);
      if (one != null) out.add(one);
    }
    return out.isEmpty ? null : out;
  }

  Future<Map<String, dynamic>?> _buildAttachmentPayload(
    String? filePath,
  ) async {
    final normalizedPath = filePath?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return null;
    }

    // File I/O is not available on web
    if (kIsWeb) {
      return null;
    }

    try {
      final file = File(normalizedPath);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      return {
        'fileName': p.basename(normalizedPath),
        'mimeType': _resolveMimeType(normalizedPath),
        'contentBase64': base64Encode(bytes),
        'localPath': normalizedPath,
      };
    } catch (_) {
      return null;
    }
  }

  String _resolveMimeType(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  // ── ID Document Verification ────────────────────────────────────────────────

  /// Calls the backend OCR verification endpoint with the ID front image.
  /// Returns a map with keys: status, confidence, extracted, reasons, verificationId.
  Future<Map<String, dynamic>> verifyIdDocument({
    required String idFrontPath,
    required String fullName,
    required String idNumber,
  }) async {
    Uint8List bytes;
    String fileName;

    if (kIsWeb) {
      // On web, retrieve bytes from LocalAttachmentStore cache
      final cached = LocalAttachmentStore.getWebBytes(idFrontPath);
      debugPrint('[verifyIdDocument] Web path: $idFrontPath, cached bytes: ${cached != null ? '${cached.length} bytes' : 'NULL'}');
      if (cached == null) {
        throw const _ApiException('ID image data not available. Please re-select the image.', retryable: false);
      }
      bytes = cached;
      // idFrontPath is like 'web:photo.jpg' — extract the filename part
      final colonIdx = idFrontPath.indexOf(':');
      fileName = colonIdx >= 0 ? idFrontPath.substring(colonIdx + 1) : idFrontPath;
    } else {
      final file = File(idFrontPath);
      if (!await file.exists()) {
        throw const _ApiException('ID front image not found.', retryable: false);
      }
      bytes = await file.readAsBytes();
      fileName = p.basename(idFrontPath);
    }

    final mimeType = _resolveMimeType(fileName);

    final uri = Uri.parse('$apiBaseUrl/verification/verify-document');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(await _headers(authorized: false))
      ..fields['userName'] = fullName
      ..fields['userIdNumber'] = idNumber
      ..fields['documentType'] = 'ID_CARD'
      ..files.add(http.MultipartFile.fromBytes(
        'file', bytes,
        filename: fileName,
        contentType: _mimeFromStr(mimeType),
      ));

    try {
      final streamed = await request.send().timeout(_kWriteTimeout);
      final responseBody = await streamed.stream.bytesToString();
      if (streamed.statusCode >= 400) {
        throw _ApiException('Verification failed: $responseBody', retryable: false);
      }
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (error) {
      if (error is _ApiException) rethrow;
      throw _ApiException('Verification service unavailable: $error', retryable: true);
    }
  }

  static MediaType _mimeFromStr(String mime) {
    try {
      return MediaType.parse(mime);
    } catch (_) {
      return MediaType('application', 'octet-stream');
    }
  }

  // Timeouts: GET = 20s (reads), POST/PATCH = 30s (writes), DELETE = 20s
  static const _kGetTimeout = Duration(seconds: 20);
  static const _kWriteTimeout = Duration(seconds: 30);

  Future<Map<String, dynamic>> _getJson(
    String path, {
    bool authorized = false,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$apiBaseUrl$path'),
            headers: headers ?? await _headers(authorized: authorized),
          )
          .timeout(
            _kGetTimeout,
            onTimeout: () => throw const _ApiException(
              'Request timed out. Please check your connection.',
              retryable: true,
            ),
          );
      return _decodeResponse(path, response);
    } catch (error) {
      if (error is _ApiException) rethrow;
      throw const _ApiException('Network unavailable.', retryable: true);
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    bool authorized = false,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$apiBaseUrl$path'),
            headers: await _headers(authorized: authorized),
            body: jsonEncode(payload),
          )
          .timeout(
            _kWriteTimeout,
            onTimeout: () => throw const _ApiException(
              'Request timed out. Please check your connection.',
              retryable: true,
            ),
          );
      return _decodeResponse(path, response);
    } catch (error) {
      if (error is _ApiException) rethrow;
      throw const _ApiException(
        'Connection to server failed. Please check your internet or the server status.',
        retryable: true,
      );
    }
  }

  Future<Map<String, dynamic>> _patchJson(
    String path,
    Map<String, dynamic> payload, {
    bool authorized = false,
  }) async {
    try {
      final response = await _client
          .patch(
            Uri.parse('$apiBaseUrl$path'),
            headers: await _headers(authorized: authorized),
            body: jsonEncode(payload),
          )
          .timeout(
            _kWriteTimeout,
            onTimeout: () => throw const _ApiException(
              'Request timed out. Please check your connection.',
              retryable: true,
            ),
          );
      return _decodeResponse(path, response);
    } catch (error) {
      if (error is _ApiException) rethrow;
      throw const _ApiException(
        'Connection to server failed. Please check your internet or the server status.',
        retryable: true,
      );
    }
  }

  Future<Map<String, dynamic>> _deleteJson(
    String path, {
    bool authorized = false,
  }) async {
    try {
      final response = await _client
          .delete(
            Uri.parse('$apiBaseUrl$path'),
            headers: await _headers(authorized: authorized),
          )
          .timeout(
            _kGetTimeout,
            onTimeout: () => throw const _ApiException(
              'Request timed out. Please check your connection.',
              retryable: true,
            ),
          );
      return _decodeResponse(path, response);
    } catch (error) {
      if (error is _ApiException) rethrow;
      throw const _ApiException(
        'Connection to server failed. Please check your internet or the server status.',
        retryable: true,
      );
    }
  }

  Future<Map<String, String>> _headers({required bool authorized}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authorized) {
      var session = await _readStoredSession();
      // Retry once — secure storage may not have persisted yet after registration
      if (session?.accessToken == null || session!.accessToken.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 300));
        session = await _readStoredSession();
      }
      final token = session?.accessToken;
      if (token == null || token.isEmpty) {
        throw const _ApiException(
          'You need to sign in before using this feature.',
          retryable: false,
          statusCode: 401,
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _decodeResponse(String path, http.Response response) {
    final body = response.body.trim();
    final decoded = body.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(body) as Map).cast<String, dynamic>();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = decoded['message'];
    final serverRetryable = decoded['retryable'];
    
    throw _ApiException(
      message is List
          ? message.join(', ')
          : (message?.toString() ?? 'Request failed: ${response.statusCode}'),
      retryable: serverRetryable is bool ? serverRetryable : response.statusCode >= 500,
      statusCode: response.statusCode,
    );
  }

  CbhiSnapshot _snapshotFromRegistration(Map<String, dynamic> json) {
    return _snapshotFromRemote(json);
  }

  CbhiSnapshot _snapshotFromRemote(Map<String, dynamic> json) {
    return CbhiSnapshot.fromJson({
      'household': json['household'] ?? <String, dynamic>{},
      'coverage': json['coverage'],
      'card': json['digitalCard'] ?? json['card'],
      'eligibility': json['eligibility'],
      'viewer': json['viewer'],
      'claims': json['claims'] ?? const <Map<String, dynamic>>[],
      'payments': json['payments'] ?? const <Map<String, dynamic>>[],
      'notifications': json['notifications'] ?? const <Map<String, dynamic>>[],
      'digitalCards': json['digitalCards'] ?? const <Map<String, dynamic>>[],
      'familyMembers': json['familyMembers'] ?? const <Map<String, dynamic>>[],
      'referrals': json['referrals'] ?? const <Map<String, dynamic>>[],
      'syncedAt':
          json['syncedAt']?.toString() ?? DateTime.now().toIso8601String(),
    });
  }

  Future<List<FamilyMember>> _applyFamilyPayload(
    Map<String, dynamic> json,
  ) async {
    final members = (json['members'] as List? ?? const [])
        .map(
          (item) =>
              FamilyMember.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList(growable: false);
    final snapshot = await loadCachedSnapshot();
    await localDb.writeSnapshot(
      snapshot.copyWith(
        familyMembers: members,
        household: {
          ...snapshot.household,
          'householdCode':
              json['householdCode']?.toString() ?? snapshot.householdCode,
          'coverageStatus':
              json['coverageStatus']?.toString() ?? snapshot.coverageStatus,
        },
        syncedAt: json['syncedAt']?.toString() ?? snapshot.syncedAt,
      ),
    );
    return members;
  }

  CbhiSnapshot _buildPendingSnapshot({
    required PersonalInfoModel personalInfo,
    required MembershipSelection membership,
    String? householdCode,
  }) {
    final now = DateTime.now().toIso8601String();
    return CbhiSnapshot(
      household: {
        'householdCode':
            householdCode ?? 'LOCAL-${DateTime.now().millisecondsSinceEpoch}',
        'address': {
          'region': personalInfo.region,
          'zone': personalInfo.zone,
          'woreda': personalInfo.woreda,
          'kebele': personalInfo.kebele,
        },
        'phoneNumber': personalInfo.phone,
        'memberCount': personalInfo.householdSize,
        'membershipType': membership.membershipType.value,
        'coverageStatus': 'PENDING_RENEWAL',
        'headUser': {
          'firstName': personalInfo.firstName,
          'middleName': personalInfo.middleName,
          'lastName': personalInfo.lastName,
          'email': personalInfo.email,
          'phoneNumber': personalInfo.phone,
          'identityVerificationStatus': 'PENDING',
          'preferredLanguage': personalInfo.preferredLanguage,
        },
        'primaryMember': {
          'fullName': personalInfo.fullName,
          'dateOfBirth': DateFormat(
            'yyyy-MM-dd',
          ).format(personalInfo.dateOfBirth),
          'gender': personalInfo.gender,
          'birthCertificateRef': personalInfo.birthCertificateRef,
          'birthCertificatePath': personalInfo.birthCertificatePath,
          'idDocumentPath': personalInfo.idDocumentPath,
        },
      },
      coverage: {
        'status': 'PENDING_RENEWAL',
        'premiumAmount': membership.isIndigent
            ? 0
            : membership.premiumAmount ?? 1200,
        'paidAmount': 0,
      },
      card: null,
      eligibility: {
        'approved': membership.isIndigent,
        'canLoginIndependently': false,
        'coverageStatus': 'PENDING_RENEWAL',
        'reason': membership.isIndigent
            ? 'Pending indigent verification while offline.'
            : 'Coverage activates after renewal payment sync.',
      },
      viewer: {'fullName': personalInfo.fullName, 'role': 'HOUSEHOLD_HEAD'},
      claims: const <Map<String, dynamic>>[],
      payments: const <Map<String, dynamic>>[],
      notifications: const <Map<String, dynamic>>[],
      digitalCards: const <Map<String, dynamic>>[],
      familyMembers: [
        FamilyMember(
          id: 'LOCAL-PRIMARY',
          membershipId: '',
          fullName: personalInfo.fullName,
          coverageStatus: 'PENDING_RENEWAL',
          isPrimaryHolder: true,
          isEligible: membership.isIndigent,
          gender: personalInfo.gender,
          dateOfBirth: DateFormat(
            'yyyy-MM-dd',
          ).format(personalInfo.dateOfBirth),
          relationshipToHouseholdHead: 'HEAD',
          birthCertificateRef: personalInfo.birthCertificateRef,
          birthCertificatePath: personalInfo.birthCertificatePath,
          idDocumentPath: personalInfo.idDocumentPath,
        ),
      ],
      syncedAt: now,
      referrals: const [],
    );
  }

  // ── Grievances ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMyGrievances() async {
    try {
      final response = await _getJson('/grievances/mine', authorized: true);
      return (response['grievances'] as List? ?? [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> submitGrievance({
    required String type,
    required String subject,
    required String description,
    String? referenceId,
    String? referenceType,
  }) async {
    return _postJson('/grievances', {
      'type': type,
      'subject': subject,
      'description': description,
      'referenceId': referenceId,
      'referenceType': referenceType,
    }, authorized: true);
  }

  // ── Benefit Package ───────────────────────────────────────────────────────

  /// Ping the backend health endpoint. Returns true if reachable.
  Future<bool> ping() async {
    try {
      await _getJson('/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getActiveBenefitPackage() async {
    try {
      return await _getJson('/benefit-packages/active');
    } catch (_) {
      return {'name': 'Standard CBHI Package', 'items': [], 'premiumPerMember': '1200', 'annualCeiling': '0'};
    }
  }

  // ── Claim Appeals ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> submitClaimAppeal({
    required String claimId,
    required String reason,
  }) async {
    return _postJson('/cbhi/claims/$claimId/appeal', {
      'reason': reason,
    }, authorized: true);
  }

  Future<List<Map<String, dynamic>>> getMyAppeals() async {
    try {
      final response = await _getJson('/cbhi/claims/appeals', authorized: true);
      return (response['appeals'] as List? ?? [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Coverage History ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCoverageHistory() async {
    try {
      final response = await _getJson('/cbhi/coverage/history', authorized: true);
      return (response['coverages'] as List? ?? [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Public HTTP wrappers (used by extension methods) ─────────────────────

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool authorized = false,
  }) => _postJson(path, body, authorized: authorized);

  Future<Map<String, dynamic>> getJson(
    String path, {
    bool authorized = false,
  }) => _getJson(path, authorized: authorized);

  /// Register or update the FCM push notification token for this user
  Future<void> registerFcmToken(String fcmToken) async {
    await _postJson('/auth/fcm-token', {'fcmToken': fcmToken}, authorized: true);
  }

  /// Remove FCM token on logout
  Future<void> removeFcmToken() async {
    try {
      await _postJson('/auth/fcm-token/remove', {}, authorized: true);
    } catch (_) {
      // Best-effort — don't block logout
    }
  }

  /// Resolves a stored media path to a displayable URL.
  /// - If the path is already an http/https URL, returns it as-is.
  /// - If the path is a relative server path (e.g. /uploads/...), prepends the API base.
  /// - If null or empty, returns an empty string.
  String resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '$apiBaseUrl$path';
    return path;
  }

  // ── Passkey (WebAuthn) endpoints ─────────────────────────────────────────

  /// Returns WebAuthn PublicKeyCredentialRequestOptions for authentication.
  Future<Map<String, dynamic>> getPasskeyAuthenticateOptions(String identifier) async {
    return _postJson(
      '/auth/passkey/authenticate-options',
      {'identifier': identifier},
    );
  }

  /// Verifies a WebAuthn assertion and returns a JWT session.
  Future<AuthSession> authenticateWithPasskey(Map<String, dynamic> dto) async {
    final json = await _postJson('/auth/passkey/authenticate', dto);
    final session = AuthSession.fromJson(json);
    await _persistSession(session);
    return session;
  }

  /// Returns WebAuthn PublicKeyCredentialCreationOptions for registration.
  Future<Map<String, dynamic>> getPasskeyRegisterOptions() async {
    return _postJson('/auth/passkey/register-options', {}, authorized: true);
  }

  /// Verifies a WebAuthn attestation and stores the passkey credential.
  Future<void> registerPasskey(Map<String, dynamic> dto) async {
    await _postJson('/auth/passkey/register', dto, authorized: true);
  }

  /// Removes a registered passkey credential.
  Future<void> removePasskey(String credentialId) async {
    await _deleteJson('/auth/passkey/$credentialId', authorized: true);
  }

  /// Lists registered passkey credentials for the current user.
  Future<List<Map<String, dynamic>>> getPasskeyCredentials() async {
    final result = await _getJson('/auth/passkey/credentials', authorized: true);
    return (result as List).cast<Map<String, dynamic>>();
  }
}
