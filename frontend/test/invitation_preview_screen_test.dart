import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_together/screens/invitation_preview_screen.dart';

void main() {
  testWidgets('invitation preview screen renders with token', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: InvitationPreviewScreen(token: 'test-token-123'),
    ));
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
