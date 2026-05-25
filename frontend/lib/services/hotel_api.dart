import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:trip_together/models/hotel_search_models.dart';
import 'package:trip_together/services/api_exception.dart';

abstract interface class IHotelApi {
  Future<HotelSearchResult> searchHotels({
    required String q,
    String? checkIn,
    String? checkOut,
    int adults,
    int limit,
  });

  void cancelOngoing();
}

class HotelApi implements IHotelApi {
  final String baseUrl;
  final Duration timeout;
  final http.Client? _httpClient;

  http.Client? _inflightClient;

  HotelApi({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 10),
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  @override
  void cancelOngoing() {
    if (_httpClient != null) {
      // If a client is injected, we cannot safely cancel by closing it.
      return;
    }
    _inflightClient?.close();
    _inflightClient = null;
  }

  @override
  Future<HotelSearchResult> searchHotels({
    required String q,
    String? checkIn,
    String? checkOut,
    int adults = 1,
    int limit = 15,
  }) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      throw ApiException.validation(message: 'City is required.');
    }

    final qp = <String, String>{
      'q': trimmed,
      'adults': adults.toString(),
      'limit': limit.toString(),
    };

    if (checkIn != null && checkIn.isNotEmpty) qp['check_in'] = checkIn;
    if (checkOut != null && checkOut.isNotEmpty) qp['check_out'] = checkOut;

    // Cancel previous inflight request (best-effort).
    cancelOngoing();

    final uri = Uri.parse(baseUrl)
        .resolve('/api/v1/hotels/search/')
        .replace(queryParameters: qp);

    final createdClient = _httpClient == null;
    final client = _httpClient ?? http.Client();
    _inflightClient = client;

    try {
      final response = await client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
            },
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final result = HotelSearchResult.fromJson((jsonDecode(response.body) as Map).cast<String, dynamic>());
        return result;
      }

      if (response.statusCode == 502) {
        debugPrint('HotelApi provider error: 502');
        throw ApiException.provider(statusCode: response.statusCode);
      }

      if (response.statusCode >= 400 && response.statusCode < 500) {
        throw ApiException.validation(
          statusCode: response.statusCode,
          message: _tryExtractErrorMessage(response.body) ?? 'Invalid request.',
        );
      }

      throw ApiException.unknown(
        statusCode: response.statusCode,
        message: _tryExtractErrorMessage(response.body) ?? 'Server error (${response.statusCode}).',
      );
    } on TimeoutException {
      debugPrint('HotelApi timeout after ${timeout.inSeconds}s');
      throw ApiException.timeout();
    } on http.ClientException catch (e) {
      debugPrint('HotelApi client exception: $e');
      throw ApiException.network(message: 'Network error. Please try again.');
    } on FormatException catch (e) {
      debugPrint('HotelApi JSON parse error: $e');
      throw ApiException.unknown(message: 'Invalid server response.');
    } finally {
      if (createdClient) {
        // Only close clients we created.
        client.close();
      }
      if (identical(_inflightClient, client)) {
        _inflightClient = null;
      }
    }
  }

  static String? _tryExtractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final map = decoded.cast<String, dynamic>();
        final detail = map['detail'];
        if (detail is String && detail.trim().isNotEmpty) return detail;

        // Common DRF validation style: { field: ["msg"] }
        for (final entry in map.entries) {
          final value = entry.value;
          if (value is List && value.isNotEmpty && value.first is String) {
            return value.first as String;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}

class ApiEnvironment {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;

    // Dev-only fallback; production builds should set API_BASE_URL.
    if (kReleaseMode) {
      throw StateError('Missing API_BASE_URL at compile time.');
    }

    return kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  }
}

