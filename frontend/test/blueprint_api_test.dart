import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_together/api_service.dart';

void main() {
  group('generateBlueprint', () {
    test('posts to blueprint endpoint with Authorization header', () async {
      String? capturedAuth;
      Uri? capturedUrl;
      final client = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        capturedUrl = request.url;
        return http.Response(jsonEncode({'token': 'bp-token'}), 201,
            headers: {'content-type': 'application/json'});
      });
      final service = ApiService(httpClient: client);
      await service.generateBlueprint('7', authToken: 'mytoken');
      expect(capturedAuth, equals('Token mytoken'));
      expect(capturedUrl.toString(), contains('/events/7/blueprint/'));
    });

    test('returns token on 201', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'token': 'bp-token-xyz'}), 201,
            headers: {'content-type': 'application/json'},
          ));
      final service = ApiService(httpClient: client);
      final result = await service.generateBlueprint('1', authToken: 'tok');
      expect(result?['token'], equals('bp-token-xyz'));
    });

    test('returns null on error', () async {
      final client = MockClient((_) async => http.Response('Forbidden', 403));
      final service = ApiService(httpClient: client);
      expect(await service.generateBlueprint('1', authToken: 'tok'), isNull);
    });
  });

  group('getBlueprint', () {
    test('returns blueprint data on 200', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'blueprint': {'title': 'Plan', 'itinerary_count': 2, 'itinerary': []},
              'created_by': 'alice',
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final service = ApiService(httpClient: client);
      final result = await service.getBlueprint('some-token');
      expect(result?['blueprint']['title'], equals('Plan'));
      expect(result?['created_by'], equals('alice'));
    });

    test('returns null on 404', () async {
      final client = MockClient((_) async => http.Response('Not Found', 404));
      final service = ApiService(httpClient: client);
      expect(await service.getBlueprint('bad'), isNull);
    });
  });

  group('copyBlueprint', () {
    test('sends Authorization header and override body', () async {
      String? capturedAuth;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'id': 99, 'title': 'Moja wersja'}), 201,
            headers: {'content-type': 'application/json'});
      });
      final service = ApiService(httpClient: client);
      await service.copyBlueprint(
        'tok',
        authToken: 'mytoken',
        title: 'Moja wersja',
        startDate: '2027-01-10',
        endDate: '2027-01-15',
      );
      expect(capturedAuth, equals('Token mytoken'));
      expect(capturedBody?['title'], equals('Moja wersja'));
      expect(capturedBody?['start_date'], equals('2027-01-10'));
      expect(capturedBody?['end_date'], equals('2027-01-15'));
    });

    test('returns new event on 201', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'id': 42, 'title': 'Skopiowane'}), 201,
            headers: {'content-type': 'application/json'},
          ));
      final service = ApiService(httpClient: client);
      final result = await service.copyBlueprint('tok', authToken: 't');
      expect(result?['id'], equals(42));
    });

    test('returns null on 400', () async {
      final client = MockClient((_) async => http.Response('Bad Request', 400));
      final service = ApiService(httpClient: client);
      expect(await service.copyBlueprint('tok', authToken: 't'), isNull);
    });
  });
}
