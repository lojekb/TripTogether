import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_together/services/auth_service.dart';

void main() {
  const baseUrl = 'http://example.com';

  test('register returns User on 201', () async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'id': 42, 'email': 'new@example.com', 'username': 'newuser'}), 201, headers: {'content-type': 'application/json'});
    });

    final svc = AuthService(baseUrl: baseUrl, client: client);
    final user = await svc.register(email: 'new@example.com', username: 'newuser', password: 'Secret123!', passwordConfirm: 'Secret123!');

    expect(user.id, 42);
    expect(user.email, 'new@example.com');
    expect(user.username, 'newuser');
  });

  test('register throws ValidationException on duplicate email', () async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'email': ['user with this email already exists.']}), 400, headers: {'content-type': 'application/json'});
    });

    final svc = AuthService(baseUrl: baseUrl, client: client);

    expect(() => svc.register(email: 'dup@example.com', username: 'dup', password: 'Secret123!', passwordConfirm: 'Secret123!'), throwsA(isA<ValidationException>()));
  });

  test('register throws ValidationException on password mismatch', () async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'password_confirm': ['Passwords do not match.']}), 400, headers: {'content-type': 'application/json'});
    });

    final svc = AuthService(baseUrl: baseUrl, client: client);

    expect(() => svc.register(email: 'a@example.com', username: 'a', password: 'one', passwordConfirm: 'two'), throwsA(isA<ValidationException>()));
  });

  group('login', () {
    test('login parses token from response', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode({'token': 'mytoken123', 'user': {'id': 1, 'email': 'x@y.com', 'username': 'x'}}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      final svc = AuthService(baseUrl: baseUrl, client: client);
      final result = await svc.login(email: 'x@y.com', password: 'Pass!');
      expect(result.token, equals('mytoken123'));
    });

    test('login parses user from response', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode({'token': 't', 'user': {'id': 5, 'email': 'a@b.com', 'username': 'alice'}}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      final svc = AuthService(baseUrl: baseUrl, client: client);
      final result = await svc.login(email: 'a@b.com', password: 'Pass!');
      expect(result.user.id, equals(5));
      expect(result.user.email, equals('a@b.com'));
    });

    test('login throws exception on 401', () async {
      final client = MockClient((_) async => http.Response('Unauthorized', 401));
      final svc = AuthService(baseUrl: baseUrl, client: client);
      expect(() => svc.login(email: 'x@y.com', password: 'wrong'), throwsException);
    });
  });
}
