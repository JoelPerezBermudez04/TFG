import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage();
  String? _accessToken;
  String? _refreshToken;

  Future<void> setTokens({required String access, required String refresh}) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> loadTokens() async {
    _accessToken = await _storage.read(key: 'access_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.deleteAll();
  }

  bool get hasTokens => _accessToken != null;
  String? get refreshToken => _refreshToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.refreshToken}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setTokens(
          access: data['access'],
          refresh: data['refresh'] ?? _refreshToken!,
        );
        return true;
      }
    } catch (_) {}

    return false;
  }

  Future<http.Response> _execute(Future<http.Response> Function(Map<String, String> headers) request) async {
    var response = await request(_headers);

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        response = await request(_headers);
      }
    }

    return response;
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    return {
      'statusCode': response.statusCode,
      'body': response.body.isNotEmpty ? jsonDecode(response.body) : null,
    };
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    final response = await _execute(
      (headers) => http.get(Uri.parse('${ApiConfig.baseUrl}$endpoint'), headers: headers),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    final body = jsonEncode(data);
    final response = await _execute(
      (headers) => http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
        body: body,
      ),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> patch(String endpoint, Map<String, dynamic> data) async {
    final body = jsonEncode(data);
    final response = await _execute(
      (headers) => http.patch(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
        body: body,
      ),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    final body = jsonEncode(data);
    final response = await _execute(
      (headers) => http.put(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
        body: body,
      ),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> delete(String endpoint, {Map<String, dynamic>? data}) async {
    final body = data != null ? jsonEncode(data) : null;
    final response = await _execute(
      (headers) => http.delete(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
        body: body,
      ),
    );
    return _parseResponse(response);
  }
}