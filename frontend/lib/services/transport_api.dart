import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:trip_together/models/transport_search_models.dart';
import 'package:trip_together/services/api_exception.dart';

abstract interface class ITransportApi {
  Future<TransportSearchResult> searchTransport({
    required String from,
    required String to,
    String? date,
    String? time,
  });

  void cancelOngoing();
}

class TransportApi implements ITransportApi {
  final String baseUrl;
  final Duration timeout;
  final http.Client? _httpClient;

  http.Client? _inflightClient;

  TransportApi({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 15),
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
  Future<TransportSearchResult> searchTransport({
    required String from,
    required String to,
    String? date,
    String? time,
  }) async {
    final fromTrimmed = from.trim();
    final toTrimmed = to.trim();
    if (fromTrimmed.isEmpty || toTrimmed.isEmpty) {
      throw ApiException.validation(message: 'Podaj początek i koniec trasy.');
    }

    final qp = <String, String>{
      'from': fromTrimmed,
      'to': toTrimmed,
    };
    if (date != null && date.isNotEmpty) qp['date'] = date;
    if (time != null && time.isNotEmpty) qp['time'] = time;

    cancelOngoing();

    final uri = Uri.parse(baseUrl)
        .resolve('/api/v1/transport/search/')
        .replace(queryParameters: qp);

    final createdClient = _httpClient == null;
    final client = _httpClient ?? http.Client();
    _inflightClient = client;

    try {
      final response = await client
          .get(
            uri,
            headers: const {'Accept': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return TransportSearchResult.fromJson(
          (jsonDecode(response.body) as Map).cast<String, dynamic>(),
        );
      }

      if (response.statusCode == 502 || response.statusCode == 503) {
        debugPrint('TransportApi provider error: ${response.statusCode}');
        throw ApiException.provider(
          statusCode: response.statusCode,
          message: _tryExtractErrorMessage(response.body) ?? 'Usługa transportu niedostępna.',
        );
      }

      if (response.statusCode >= 400 && response.statusCode < 500) {
        throw ApiException.validation(
          statusCode: response.statusCode,
          message: _tryExtractErrorMessage(response.body) ?? 'Nieprawidłowe zapytanie.',
        );
      }

      throw ApiException.unknown(
        statusCode: response.statusCode,
        message: _tryExtractErrorMessage(response.body) ?? 'Błąd serwera (${response.statusCode}).',
      );
    } on TimeoutException {
      debugPrint('TransportApi timeout after ${timeout.inSeconds}s');
      throw ApiException.timeout();
    } on http.ClientException catch (e) {
      debugPrint('TransportApi client exception: $e');
      throw ApiException.network(message: 'Błąd sieci. Spróbuj ponownie.');
    } on FormatException catch (e) {
      debugPrint('TransportApi JSON parse error: $e');
      throw ApiException.unknown(message: 'Nieprawidłowa odpowiedź serwera.');
    } finally {
      if (createdClient) {
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
