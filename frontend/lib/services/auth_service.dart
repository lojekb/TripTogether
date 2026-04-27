import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:trip_together/models/user.dart';

class ValidationException implements Exception {
  final Map<String, List<String>> errors;
  ValidationException(this.errors);

  @override
  String toString() => 'ValidationException: $errors';
}

class AuthService {
  final String baseUrl;
  http.Client? _client;

  AuthService({required this.baseUrl, http.Client? client}) : _client = client;

  http.Client get _httpClient => _client ??= http.Client();

  /// Register a user. On success returns [User]. On validation errors throws [ValidationException].
  Future<User> register({
    required String email,
    required String username,
    required String password,
    required String passwordConfirm,
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/auth/register/');
    final body = jsonEncode({
      'email': email,
      'username': username,
      'password': password,
      'password_confirm': passwordConfirm,
    });

    try {
      final resp = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return User.fromJson(data);
      }

      if (resp.statusCode == 400) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        // Normalize errors to Map<String, List<String>>
        final Map<String, List<String>> errors = {};
        data.forEach((key, value) {
          if (value is List) {
            errors[key] = value.map((e) => e.toString()).toList();
          } else {
            errors[key] = [value.toString()];
          }
        });
        throw ValidationException(errors);
      }

      throw Exception('Server error: ${resp.statusCode}');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Login with email and password. Expects backend at POST {baseUrl}/api/v1/auth/login/
  /// Returns User on success (HTTP 200). Throws [ValidationException] on 400.
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/auth/login/');
    final body = jsonEncode({'email': email, 'password': password});

    try {
      final resp = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        // Response shape may be {"user": {...}} or {...}
        if (data is Map<String, dynamic>) {
          final Map<String, dynamic> map = data;
          final userPayload = (map['user'] is Map) ? Map<String, dynamic>.from(map['user'] as Map) : map;
          return User.fromJson(userPayload);
        }
        throw Exception('Unexpected login response shape');
      }

      if (resp.statusCode == 400) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final Map<String, List<String>> errors = {};
        data.forEach((key, value) {
          if (value is List) {
            errors[key] = value.map((e) => e.toString()).toList();
          } else {
            errors[key] = [value.toString()];
          }
        });
        throw ValidationException(errors);
      }

      throw Exception('Server error: ${resp.statusCode}');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
