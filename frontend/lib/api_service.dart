import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:trip_together/api_constants.dart';

class ApiService {
  final http.Client? _httpClient;

  ApiService({http.Client? httpClient}) : _httpClient = httpClient;

  http.Client get _client => _httpClient ?? http.Client();

  Future<List<dynamic>> getEvents({String? token}) async {
    try {
      final url = Uri.parse(ApiConstants.baseUrl + ApiConstants.eventsEndpoint);
      final headers = <String, String>{};
      if (token != null) {
        headers['Authorization'] = 'Token $token';
      }
      final response = await _client.get(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Błąd serwera: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Błąd połączenia: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> generateInvitation(
    String eventId, {
    required String authToken,
  }) async {
    try {
      final url = Uri.parse(
        '${ApiConstants.baseUrl}/events/$eventId/invitations/',
      );
      final response = await _client.post(
        url,
        headers: {'Authorization': 'Token $authToken'},
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('generateInvitation błąd: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('generateInvitation błąd połączenia: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getInvitation(String token) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/invitations/$token/');
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('getInvitation błąd: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('getInvitation błąd połączenia: $e');
      return null;
    }
  }

  Future<bool> joinEvent(String token, {required String authToken}) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/invitations/$token/join/');
      final response = await _client.post(
        url,
        headers: {'Authorization': 'Token $authToken'},
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('joinEvent błąd połączenia: $e');
      return false;
    }
  }

  Future<List<dynamic>> getNotifications({required String authToken}) async {
    try {
      final url = Uri.parse(
        ApiConstants.baseUrl + ApiConstants.notificationsEndpoint,
      );
      final response = await _client.get(
        url,
        headers: {'Authorization': 'Token $authToken'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      debugPrint('getNotifications błąd: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('getNotifications błąd połączenia: $e');
      return [];
    }
  }

  Future<bool> markNotificationRead({
    required String authToken,
    required String notificationId,
  }) async {
    try {
      final url = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.notificationsEndpoint}$notificationId/read/',
      );
      final response = await _client.put(
        url,
        headers: {'Authorization': 'Token $authToken'},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('markNotificationRead błąd połączenia: $e');
      return false;
    }
  }
}
