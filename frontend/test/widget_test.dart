import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_together/main.dart'; // Upewnij się, że nazwa paczki to trip_together

void main() {
  testWidgets('Aplikacja uruchamia się i wyświetla ekran główny', (WidgetTester tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.text('TripTogether Events'), findsOneWidget);
    
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}