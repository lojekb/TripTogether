import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_together/pages/registration_page.dart';
import 'package:trip_together/services/auth_service.dart';
import 'package:trip_together/models/user.dart';

class TestAuthService extends AuthService {
  final Future<void> Function()? onRegister;
  final bool shouldFail;
  final Map<String, List<String>> errors;

  TestAuthService({String baseUrl = 'http://test', this.onRegister, this.shouldFail = false, this.errors = const {}}) : super(baseUrl: baseUrl);

  @override
  Future<User> register({required String email, required String username, required String password, required String passwordConfirm}) async {
    if (onRegister != null) await onRegister!();
    if (shouldFail) throw ValidationException(errors);
    // return a dummy user when successful
    return Future.value(User(id: 1, email: email, username: username));
  }
}

void main() {
  testWidgets('registration page shows validation and server errors', (WidgetTester tester) async {
    final testService = TestAuthService(shouldFail: true, errors: {'email': ['user with this email already exists.']});

    final model = RegistrationModel(authService: testService);

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<RegistrationModel>.value(
        value: model,
        child: RegistrationPage(baseUrl: 'http://test', model: model),
      ),
    ));

    // Initially, Register button disabled because form invalid
    final registerButton = find.widgetWithText(ElevatedButton, 'Register');
    expect(registerButton, findsOneWidget);
    final initialButton = tester.widget<ElevatedButton>(registerButton);
    expect(initialButton.onPressed == null, isTrue);

    // Fill valid values
    await tester.enterText(find.byType(TextFormField).at(0), 'new@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'newuser');
    await tester.enterText(find.byType(TextFormField).at(2), 'Secret123!');
    await tester.enterText(find.byType(TextFormField).at(3), 'Secret123!');
    await tester.pumpAndSettle();

    // Now button should be enabled
    final elevated = tester.widget<ElevatedButton>(registerButton);
    expect(elevated.onPressed != null, isTrue);

    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    // Should show an inline error for email field from server
    expect(find.text('user with this email already exists.'), findsOneWidget);
  });
}
