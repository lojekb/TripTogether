import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_together/api_service.dart';

void main() {
  test('getEvents sends Authorization header with token', () async {
    String? capturedAuth;
    final client = MockClient((request) async {
      capturedAuth = request.headers['Authorization'];
      return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
    });

    final service = ApiService(httpClient: client);
    await service.getEvents(token: 'abc123');

    expect(capturedAuth, equals('Token abc123'));
  });

  test('getEvents returns empty list on 401', () async {
    final client = MockClient((_) async => http.Response('Unauthorized', 401));
    final service = ApiService(httpClient: client);
    final result = await service.getEvents(token: 'bad');
    expect(result, isEmpty);
  });

  test('getEvents returns empty list on network error', () async {
    final client = MockClient((_) async => throw http.ClientException('timeout'));
    final service = ApiService(httpClient: client);
    final result = await service.getEvents(token: 'any');
    expect(result, isEmpty);
  });
}
