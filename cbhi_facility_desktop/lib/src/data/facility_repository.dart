import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kFacilityApiBase = String.fromEnvironment(
  'CBHI_API_BASE_URL',
  defaultValue: 'https://member-based-cbhi.vercel.app/api/v1',
);

class FacilityRepository {
  FacilityRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;
  static const _tokenKey = 'cbhi_facility_token';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<Map<String, dynamic>> login({required String identifier, required String password}) async {
    final response = await _post('/auth/login', {'identifier': identifier, 'password': password});
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
          .get(Uri.parse('$kFacilityApiBase/health'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> verifyEligibility({
    String? membershipId,
    String? phoneNumber,
    String? householdCode,
    String? fullName,
  }) async {
    final query = <String, String>{
      if (membershipId != null && membershipId.isNotEmpty) 'membershipId': membershipId,
      if (phoneNumber != null && phoneNumber.isNotEmpty && phoneNumber != '+2519') 'phoneNumber': phoneNumber,
      if (householdCode != null && householdCode.isNotEmpty) 'householdCode': householdCode,
      if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
    };
    final qs = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return _get('/facility/eligibility$qs');
  }

  Future<Map<String, dynamic>> submitClaim({
    String? membershipId,
    String? phoneNumber,
    String? householdCode,
    String? fullName,
    required String serviceDate,
    required List<Map<String, dynamic>> items,
    String? supportingDocumentPath,
    Map<String, dynamic>? supportingDocumentUpload,
  }) async {
    return _post('/facility/claims', {
      'membershipId': membershipId,
      'phoneNumber': phoneNumber,
      'householdCode': householdCode,
      'fullName': fullName,
      'serviceDate': serviceDate,
      'items': items,
      'supportingDocumentUpload': ?supportingDocumentUpload,
    });
  }

  Future<List<Map<String, dynamic>>> getClaims() async {
    final response = await _get('/facility/claims');
    return _asList(response['claims']);
  }

  /// Fetch the active benefit package catalog for service selection
  Future<List<Map<String, dynamic>>> getBenefitPackageItems() async {
    try {
      final response = await _get('/benefit-packages');
      final packages = _asList(response['packages'] ?? response);
      if (packages.isEmpty) return [];
      // Return items from the first active package
      final items = packages.first['items'];
      return _asList(items);
    } catch (_) {
      return [];
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _get('/notifications');
    return _asList(response);
  }

  Future<void> markNotificationRead(String notificationId) async {
    final response = await _client
        .patch(
          Uri.parse('$kFacilityApiBase/notifications/$notificationId/read'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));
    _parse(response);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _client
        .get(Uri.parse('$kFacilityApiBase$path'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _parse(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          Uri.parse('$kFacilityApiBase$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _parse(response);
  }

  Map<String, dynamic> _parse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) throw Exception((body as Map)['message']?.toString() ?? 'Request failed');
    return (body as Map).cast<String, dynamic>();
  }

  List<Map<String, dynamic>> _asList(dynamic value) =>
      (value as List? ?? []).map((item) => (item as Map).cast<String, dynamic>()).toList();
}
