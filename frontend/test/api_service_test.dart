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

  group('generateInvitation', () {
    test('sends Authorization header', () async {
      String? capturedAuth;
      final client = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        return http.Response(jsonEncode({'token': 'abc', 'expires_at': '2026-04-29T00:00:00Z'}), 201,
            headers: {'content-type': 'application/json'});
      });
      final service = ApiService(httpClient: client);
      await service.generateInvitation('1', authToken: 'mytoken');
      expect(capturedAuth, equals('Token mytoken'));
    });

    test('returns token on 201', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'token': 'invite-token-xyz', 'expires_at': '2026-04-29T00:00:00Z'}),
            201, headers: {'content-type': 'application/json'},
          ));
      final service = ApiService(httpClient: client);
      final result = await service.generateInvitation('1', authToken: 'tok');
      expect(result?['token'], equals('invite-token-xyz'));
    });

    test('returns null on error', () async {
      final client = MockClient((_) async => http.Response('Forbidden', 403));
      final service = ApiService(httpClient: client);
      final result = await service.generateInvitation('1', authToken: 'tok');
      expect(result, isNull);
    });
  });

  group('getInvitation', () {
    test('returns event data on 200', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'event': {'title': 'Trip'}, 'inviter': 'alice', 'expires_at': '2026-04-29T00:00:00Z'}),
            200, headers: {'content-type': 'application/json'},
          ));
      final service = ApiService(httpClient: client);
      final result = await service.getInvitation('some-token');
      expect(result?['event']['title'], equals('Trip'));
    });

    test('returns null on 404', () async {
      final client = MockClient((_) async => http.Response('Not Found', 404));
      final service = ApiService(httpClient: client);
      expect(await service.getInvitation('bad'), isNull);
    });

    test('returns null on 410', () async {
      final client = MockClient((_) async => http.Response('Gone', 410));
      final service = ApiService(httpClient: client);
      expect(await service.getInvitation('expired'), isNull);
    });
  });

  group('joinEvent', () {
    test('sends Authorization header', () async {
      String? capturedAuth;
      final client = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        return http.Response('{"message":"ok"}', 201, headers: {'content-type': 'application/json'});
      });
      final service = ApiService(httpClient: client);
      await service.joinEvent('tok', authToken: 'mytoken');
      expect(capturedAuth, equals('Token mytoken'));
    });

    test('returns true on 201', () async {
      final client = MockClient((_) async => http.Response('{"message":"ok"}', 201,
          headers: {'content-type': 'application/json'}));
      final service = ApiService(httpClient: client);
      expect(await service.joinEvent('tok', authToken: 't'), isTrue);
    });

    test('returns false on 409 (already member)', () async {
      final client = MockClient((_) async => http.Response('Conflict', 409));
      final service = ApiService(httpClient: client);
      expect(await service.joinEvent('tok', authToken: 't'), isFalse);
    });

    test('returns false on 410 (expired)', () async {
      final client = MockClient((_) async => http.Response('Gone', 410));
      final service = ApiService(httpClient: client);
      expect(await service.joinEvent('tok', authToken: 't'), isFalse);
    });
  });
}
