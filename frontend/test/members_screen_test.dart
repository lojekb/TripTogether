import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:trip_together/screens/members_screen.dart';
import 'package:trip_together/services/auth_service.dart';
import 'package:trip_together/services/auth_state.dart';

const _members = [
  {'id': 1, 'user_id': 10, 'username': 'owner', 'email': 'o@x.com', 'role': 'OWNER'},
  {'id': 2, 'user_id': 20, 'username': 'kasia', 'email': 'k@x.com', 'role': 'MEMBER'},
];

AuthState _loggedIn() =>
    AuthState(authService: AuthService(baseUrl: 'http://x'))..token = 'tok';

http.Response _membersResponse() => http.Response(
      jsonEncode(_members), 200, headers: {'content-type': 'application/json'});

Widget _wrap(Widget screen, AuthState auth) => ChangeNotifierProvider<AuthState>.value(
      value: auth,
      child: MaterialApp(home: screen),
    );

void main() {
  testWidgets('manager sees management title and edit button', (tester) async {
    final client = MockClient((_) async => _membersResponse());
    await tester.pumpWidget(_wrap(
      MembersScreen(
        eventId: '1',
        eventTitle: 'Wyjazd',
        canManageRoles: true,
        currentUserRole: 'OWNER',
        client: client,
      ),
      _loggedIn(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Zarządzanie wydarzeniem'), findsOneWidget);
    expect(find.byKey(const Key('editEventDetailsButton')), findsOneWidget);
  });

  testWidgets('non-manager sees participants title and no edit button', (tester) async {
    final client = MockClient((_) async => _membersResponse());
    await tester.pumpWidget(_wrap(
      MembersScreen(
        eventId: '1',
        eventTitle: 'Wyjazd',
        canManageRoles: false,
        currentUserRole: 'MEMBER',
        client: client,
      ),
      _loggedIn(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Uczestnicy'), findsOneWidget);
    expect(find.byKey(const Key('editEventDetailsButton')), findsNothing);
  });

  testWidgets('removing a member sends DELETE to the member endpoint', (tester) async {
    String? deletedPath;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deletedPath = request.url.path;
        return http.Response(jsonEncode({'detail': 'ok'}), 200,
            headers: {'content-type': 'application/json'});
      }
      return _membersResponse();
    });

    await tester.pumpWidget(_wrap(
      MembersScreen(
        eventId: '1',
        eventTitle: 'Wyjazd',
        canManageRoles: true,
        currentUserRole: 'OWNER',
        client: client,
      ),
      _loggedIn(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('removeMember_20')));
    await tester.pumpAndSettle();
    // Confirm dialog
    await tester.tap(find.widgetWithText(TextButton, 'Usuń'));
    await tester.pumpAndSettle();

    expect(deletedPath, equals('/api/v1/events/1/members/20/'));
  });

  testWidgets('editing details sends PUT with the new title', (tester) async {
    Map<String, dynamic>? putBody;
    final client = MockClient((request) async {
      if (request.method == 'PUT') {
        putBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'title': 'Nowa nazwa'}), 200,
            headers: {'content-type': 'application/json'});
      }
      return _membersResponse();
    });

    await tester.pumpWidget(_wrap(
      MembersScreen(
        eventId: '1',
        eventTitle: 'Wyjazd',
        canManageRoles: true,
        currentUserRole: 'OWNER',
        client: client,
        event: const {
          'title': 'Wyjazd',
          'destination_city': 'Kraków',
          'destination_country': 'Poland',
          'start_date': '2026-08-01',
          'end_date': '2026-08-05',
          'description': '',
        },
      ),
      _loggedIn(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editEventDetailsButton')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('editEvent_title')), 'Nowa nazwa');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Zapisz'));
    await tester.pumpAndSettle();

    expect(putBody?['title'], equals('Nowa nazwa'));
  });
}
