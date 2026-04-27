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
}