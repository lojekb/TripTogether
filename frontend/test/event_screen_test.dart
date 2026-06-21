import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_together/services/auth_state.dart';
import 'package:trip_together/services/auth_service.dart';
import 'package:trip_together/main.dart';

class _StubAuthService extends AuthService {
  _StubAuthService() : super(baseUrl: 'http://test');
}

Widget _buildApp() {
  final authState = AuthState(authService: _StubAuthService());
  return ChangeNotifierProvider<AuthState>.value(
    value: authState,
    child: MaterialApp(
      routes: {
        '/login': (_) => const Scaffold(body: Text('Login')),
        '/register': (_) => const Scaffold(body: Text('Register')),
      },
      home: const EventScreen(),
    ),
  );
}

void main() {
  testWidgets('login button visible when not logged in', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    expect(find.widgetWithText(TextButton, 'Login'), findsOneWidget);
  });

  testWidgets('register button visible when not logged in', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    expect(find.widgetWithText(TextButton, 'Register'), findsOneWidget);
  });

  testWidgets('spinner not shown when not logged in', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('events list not shown when not logged in', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    expect(find.byType(ListView), findsNothing);
  });
}
