import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kFacilityApiBase = String.fromEnvironment(
  'CBHI_API_BASE_URL',
  defaultValue: 'https://member-based-cbhi.vercel.app/api/v1',
);

/// Normalize the API base URL at runtime:
/// - Strip trailing slash
/// - Ensure it ends with /api/v1
String get _normalizedFacilityApiBase {
  var url = kFacilityApiBase.trimRight();
  if (url.endsWith('/')) url = url.substring(0, url.length - 1);
  if (!url.endsWith('/api/v1')) url = '$url/api/v1';
  return url;
}

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
          .get(Uri.parse('$_normalizedFacilityApiBase/health'), headers: _headers)
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
      if (supportingDocumentUpload != null)
        'supportingDocumentUpload': supportingDocumentUpload,
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
          Uri.parse('$_normalizedFacilityApiBase/notifications/$notificationId/read'),
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
    try {
      final response = await _client
          .get(Uri.parse('$_normalizedFacilityApiBase$path'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      return _parse(response);
    } catch (e) {
      if (e is Exception && !e.toString().contains('HTTP')) {
        throw Exception('Network error: Unable to reach the facility server. Please check your connection.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_normalizedFacilityApiBase$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      return _parse(response);
    } catch (e) {
      if (e is Exception && !e.toString().contains('HTTP')) {
        throw Exception('Network error: Request failed. Please check your internet connection.');
      }
      rethrow;
    }
  }

  Map<String, dynamic> _parse(http.Response response) {
    final rawBody = response.body.trim();
    if (rawBody.isEmpty) {
      if (response.statusCode >= 400) throw Exception('Request failed with status: ${response.statusCode}');
      return {};
    }

    Map<String, dynamic> body;
    try {
      body = (jsonDecode(rawBody) as Map).cast<String, dynamic>();
    } catch (_) {
      throw Exception('Server returned invalid data (HTTP ${response.statusCode}).');
    }

    if (response.statusCode >= 400) {
      final msg = body['message'];
      final retryable = body['retryable'] == true;
      final errorPrefix = retryable ? '[Retryable] ' : '';

      throw Exception(
        '$errorPrefix${msg is List ? msg.join(', ') : (msg?.toString() ?? 'Request failed (${response.statusCode})')}',
      );
    }
    return body;
  }

  List<Map<String, dynamic>> _asList(dynamic value) =>
      (value as List? ?? []).map((item) => (item as Map).cast<String, dynamic>()).toList();
}
