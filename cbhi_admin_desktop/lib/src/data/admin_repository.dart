import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kAdminApiBase = String.fromEnvironment(
  'CBHI_API_BASE_URL',
  defaultValue: 'https://member-based-cbhi.vercel.app/api/v1',
);

class AdminRepository {
  AdminRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;

  static const _tokenKey = 'cbhi_admin_token';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _post('/auth/login', {
      'identifier': identifier,
      'password': password,
    });
    _token = response['accessToken']?.toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token ?? '');
    return response;
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<void> registerFcmToken(String token) async {
    await _post('/auth/fcm-token', {'fcmToken': token});
  }

  /// Returns true if the backend is reachable
  Future<bool> ping() async {
    try {
      final response = await _client
          .get(Uri.parse('$kAdminApiBase/health'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getSummaryReport({String? from, String? to}) async {
    final query = <String, String>{
      'from': from ?? '',
      'to': to ?? '',
    };
    final qs = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return _get('/admin/reports/summary$qs');
  }

  Future<List<Map<String, dynamic>>> getClaims() async {
    final response = await _get('/admin/claims');
    return _asList(response['claims']);
  }

  Future<Map<String, dynamic>> reviewClaim({
    required String claimId,
    required String status,
    double? approvedAmount,
    String? decisionNote,
  }) async {
    return _patch('/admin/claims/$claimId/decision', {
      'status': status,
      'approvedAmount': approvedAmount,
      'decisionNote': decisionNote,
    });
  }

  Future<List<Map<String, dynamic>>> getConfiguration() async {
    final response = await _get('/admin/configuration');
    return _asList(response['settings']);
  }

  Future<void> updateConfiguration({
    required String key,
    required Map<String, dynamic> value,
    String? label,
    String? description,
  }) async {
    await _put('/admin/configuration/$key', {
      'value': value,
      'label': label,
      'description': description,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingIndigent() async {
    final response = await _get('/admin/indigent/pending');
    return _asList(response['applications']);
  }

  Future<void> reviewIndigent({
    required String applicationId,
    required String status,
    String? reason,
  }) async {
    await _patch('/admin/indigent/$applicationId/review', {
      'status': status,
      'reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> listFacilities() async {
    final response = await _get('/admin/facilities');
    return _asList(response['facilities']);
  }

  Future<Map<String, dynamic>> createFacility({
    required String name,
    String? facilityCode,
    String? serviceLevel,
    String? phoneNumber,
    String? addressLine,
  }) async {
    return _post('/admin/facilities', {
      'name': name,
      'facilityCode': ?facilityCode,
      'serviceLevel': ?serviceLevel,
      'phoneNumber': ?phoneNumber,
      'addressLine': ?addressLine,
    });
  }

  Future<void> addFacilityStaff({
    required String facilityId,
    required String identifier,
    String? firstName,
    String? lastName,
  }) async {
    await _post('/admin/facilities/$facilityId/staff', {
      'identifier': identifier,
      'firstName': ?firstName,
      'lastName': ?lastName,
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? entityType,
    String? entityId,
  }) async {
    final query = <String, String>{
      'entityType': ?entityType,
      'entityId': ?entityId,
    };
    final qs = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final response = await _get('/admin/audit-logs$qs');
    return _asList(response['logs']);
  }

  Future<String> exportCsv({
    required String type,
    String? from,
    String? to,
  }) async {
    final query = <String, String>{
      'type': type,
      'from': from ?? '',
      'to': to ?? '',
    };
    final qs = '?${Uri(queryParameters: query).query}';
    final response = await _client.get(
      Uri.parse('$kAdminApiBase/admin/export$qs'),
      headers: _headers,
    );
    if (response.statusCode != 200) throw Exception('Export failed');
    return response.body;
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _get('/notifications');
    return _asList(response);
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _patch('/notifications/$notificationId/read', {});
  }

  // ── Benefit Packages ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBenefitPackages() async {
    final response = await _get('/benefit-packages');
    return _asList(response['packages'] ?? response);
  }

  Future<Map<String, dynamic>> createBenefitPackage({
    required String name,
    String? description,
    required double premiumPerMember,
    double annualCeiling = 0,
  }) async {
    return _post('/benefit-packages', {
      'name': name,
      'description': ?description,
      'premiumPerMember': premiumPerMember,
      'annualCeiling': annualCeiling,
    });
  }

  Future<Map<String, dynamic>> addBenefitItem({
    required String packageId,
    required String serviceName,
    String? serviceCode,
    required String category,
    double maxClaimAmount = 0,
    int coPaymentPercent = 0,
    int maxClaimsPerYear = 0,
  }) async {
    return _post('/benefit-packages/$packageId/items', {
      'serviceName': serviceName,
      'serviceCode': ?serviceCode,
      'category': category,
      'maxClaimAmount': maxClaimAmount,
      'coPaymentPercent': coPaymentPercent,
      'maxClaimsPerYear': maxClaimsPerYear,
    });
  }

  Future<Map<String, dynamic>> updateBenefitItem(String itemId, {bool? isCovered}) async {
    return _patch('/benefit-packages/items/$itemId', {
      'isCovered': ?isCovered,
    });
  }

  // ── Grievances ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllGrievances({String? status}) async {
    final qs = status != null ? '?status=$status' : '';
    final response = await _get('/grievances$qs');
    return _asList(response['grievances']);
  }

  Future<Map<String, dynamic>> updateGrievance({
    required String grievanceId,
    String? status,
    String? resolution,
  }) async {
    return _patch('/grievances/$grievanceId', {
      'status': ?status,
      'resolution': ?resolution,
    });
  }

  // ── User Management ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listUsers({String? role}) async {
    final qs = role != null ? '?role=$role' : '';
    final response = await _get('/admin/users$qs');
    return _asList(response['users']);
  }

  Future<void> deactivateUser(String userId) async {
    await _patch('/admin/users/$userId/deactivate', {});
  }

  Future<void> activateUser(String userId) async {
    await _patch('/admin/users/$userId/activate', {});
  }

  Future<void> resetUserPassword(String userId) async {
    await _post('/admin/users/$userId/reset-password', {});
  }

  // ── Claim Appeals ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllAppeals() async {
    final response = await _get('/admin/claims/appeals');
    return _asList(response['appeals'] ?? response);
  }

  Future<Map<String, dynamic>> reviewAppeal({
    required String appealId,
    required String status,
    String? reviewNote,
  }) async {
    return _patch('/admin/claims/appeals/$appealId/review', {
      'status': status,
      if (reviewNote != null && reviewNote.isNotEmpty) 'reviewNote': reviewNote,
    });
  }

  // ── Financial Dashboard ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getFinancialDashboard({String? from, String? to}) async {
    final query = <String, String>{
      'from': ?from,
      'to': ?to,
    };
    final qs = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return _get('/admin/reports/financial$qs');
  }

  // ── TOTP 2FA ──────────────────────────────────────────────────────────────

  /// Initiates TOTP setup — returns { secret, qrUri }
  Future<Map<String, dynamic>> setupTotp() async {
    return _post('/auth/totp/setup', {});
  }

  /// Activates TOTP after the user verifies the first token
  Future<void> activateTotp(String token) async {
    await _post('/auth/totp/activate', {'token': token});
  }

  // ── Facility Performance ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFacilityPerformance({String? from, String? to}) async {
    final query = <String, String>{
      'from': ?from,
      'to': ?to,
    };
    final qs = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final response = await _get('/admin/reports/facility-performance$qs');
    return _asList(response['facilities'] ?? response);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _client
        .get(Uri.parse('$kAdminApiBase$path'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _parse(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          Uri.parse('$kAdminApiBase$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _parse(response);
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    final response = await _client
        .patch(
          Uri.parse('$kAdminApiBase$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _parse(response);
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final response = await _client
        .put(
          Uri.parse('$kAdminApiBase$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _parse(response);
  }

  Map<String, dynamic> _parse(http.Response response) {
    final rawBody = response.body.trim();

    // Guard against non-JSON responses (HTML error pages, gateway errors, etc.)
    Map<String, dynamic> body;
    try {
      body = (jsonDecode(rawBody) as Map).cast<String, dynamic>();
    } catch (_) {
      throw Exception(
        'Server returned an unexpected response (HTTP ${response.statusCode}). '
        'Check that the API is reachable.',
      );
    }

    if (response.statusCode >= 400) {
      final msg = body['message'];
      throw Exception(
        msg is List
            ? msg.join(', ')
            : msg?.toString() ?? 'Request failed (${response.statusCode})',
      );
    }
    return body;
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    return (value as List? ?? [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }
}
