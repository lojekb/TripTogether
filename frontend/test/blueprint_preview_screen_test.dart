import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:trip_together/api_service.dart';
import 'package:trip_together/screens/blueprint_preview_screen.dart';
import 'package:trip_together/services/auth_service.dart';
import 'package:trip_together/services/auth_state.dart';

ApiService _serviceReturning(Map<String, dynamic> body) {
  final client = MockClient((_) async => http.Response(
        jsonEncode(body), 200, headers: {'content-type': 'application/json'}));
  return ApiService(httpClient: client);
}

void main() {
  setUp(() {
    pendingBlueprintToken = null;
    pendingBlueprintEdits = null;
  });

  testWidgets('shows loading indicator before data arrives', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BlueprintPreviewScreen(token: 'tok', apiService: _serviceReturning({})),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('prefills title field and lists itinerary after load', (tester) async {
    final service = _serviceReturning({
      'blueprint': {
        'title': 'Weekend w Krakowie',
        'destination_city': 'Kraków',
        'destination_country': 'Poland',
        'start_date': '2026-06-01',
        'end_date': '2026-06-05',
        'description': '',
        'itinerary_count': 2,
        'itinerary': [
          {'title': 'Wawel', 'item_type': 'ATTRACTION'},
          {'title': 'Hotel Stary', 'item_type': 'HOTEL'},
        ],
      },
      'created_by': 'alice',
    });

    await tester.pumpWidget(MaterialApp(
      home: BlueprintPreviewScreen(token: 'tok', apiService: service),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Weekend w Krakowie'), findsWidgets);
    expect(find.text('Wawel'), findsOneWidget);
    expect(find.text('Hotel Stary'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Utwórz moje wydarzenie'), findsOneWidget);
  });

  testWidgets('tapping start date field opens a date picker', (tester) async {
    final service = _serviceReturning({
      'blueprint': {
        'title': 'Weekend',
        'destination_city': 'Kraków',
        'destination_country': 'Poland',
        'start_date': '2026-06-01',
        'end_date': '2026-06-05',
        'description': '',
        'itinerary_count': 0,
        'itinerary': [],
      },
      'created_by': 'alice',
    });

    await tester.pumpWidget(MaterialApp(
      home: BlueprintPreviewScreen(token: 'tok', apiService: service),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('startDateField')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
  });

  testWidgets('autoCopy triggers the copy request when already logged in', (tester) async {
    var copyCalled = false;
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/copy/')) {
        copyCalled = true;
        return http.Response('Bad Request', 400);
      }
      return http.Response(
        jsonEncode({
          'blueprint': {
            'title': 'Plan',
            'destination_city': 'Kraków',
            'destination_country': 'Poland',
            'start_date': '2026-06-01',
            'end_date': '2026-06-05',
            'description': '',
            'itinerary_count': 0,
            'itinerary': [],
          },
          'created_by': 'alice',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final authState = AuthState(authService: AuthService(baseUrl: 'http://x'))
      ..token = 'logged-in-token';

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthState>.value(
        value: authState,
        child: MaterialApp(
          home: BlueprintPreviewScreen(
            token: 'tok',
            autoCopy: true,
            apiService: ApiService(httpClient: client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(copyCalled, isTrue);
  });

  testWidgets('successful copy returns to a fresh home screen', (tester) async {
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/copy/')) {
        return http.Response(jsonEncode({'id': 5, 'title': 'Skopiowane'}), 201,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(
        jsonEncode({
          'blueprint': {
            'title': 'Plan',
            'destination_city': 'Kraków',
            'destination_country': 'Poland',
            'start_date': '2026-06-01',
            'end_date': '2026-06-05',
            'description': '',
            'itinerary_count': 0,
            'itinerary': [],
          },
          'created_by': 'alice',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final authState = AuthState(authService: AuthService(baseUrl: 'http://x'))
      ..token = 'logged-in-token';

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthState>.value(
        value: authState,
        child: MaterialApp(
          initialRoute: '/start',
          routes: {
            '/': (_) => const Scaffold(body: Text('HOME_SCREEN')),
            '/start': (_) => BlueprintPreviewScreen(
                  token: 'tok',
                  apiService: ApiService(httpClient: client),
                ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Utwórz moje wydarzenie'));
    await tester.pumpAndSettle();

    expect(find.text('HOME_SCREEN'), findsOneWidget);
    expect(find.byType(BlueprintPreviewScreen), findsNothing);
  });

  testWidgets('autoCopy applies edits captured before login', (tester) async {
    Map<String, dynamic>? capturedBody;
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/copy/')) {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('Bad Request', 400);
      }
      return http.Response(
        jsonEncode({
          'blueprint': {
            'title': 'Plan',
            'destination_city': 'Kraków',
            'destination_country': 'Poland',
            'start_date': '2026-06-01',
            'end_date': '2026-06-05',
            'description': '',
            'itinerary_count': 0,
            'itinerary': [],
          },
          'created_by': 'alice',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    pendingBlueprintEdits = {
      'title': 'Edytowana nazwa',
      'start_date': '2027-02-01',
      'end_date': '2027-02-10',
    };

    final authState = AuthState(authService: AuthService(baseUrl: 'http://x'))
      ..token = 'logged-in-token';

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthState>.value(
        value: authState,
        child: MaterialApp(
          home: BlueprintPreviewScreen(
            token: 'tok',
            autoCopy: true,
            apiService: ApiService(httpClient: client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(capturedBody?['title'], equals('Edytowana nazwa'));
    expect(capturedBody?['start_date'], equals('2027-02-01'));
    expect(capturedBody?['end_date'], equals('2027-02-10'));
  });

  testWidgets('shows error when blueprint not found', (tester) async {
    final client = MockClient((_) async => http.Response('Not Found', 404));
    await tester.pumpWidget(MaterialApp(
      home: BlueprintPreviewScreen(token: 'bad', apiService: ApiService(httpClient: client)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('nie istnieje'), findsOneWidget);
  });
}
