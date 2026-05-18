import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_together/screens/event_details_screen.dart';

void main() {
  testWidgets('EventDetailsScreen displays all required tabs', (WidgetTester tester) async {
    final event = {
      'id': 1,
      'title': 'Test Trip',
      'destination_city': 'Paris',
      'destination_country': 'France',
    };

    await tester.pumpWidget(MaterialApp(
      home: EventDetailsScreen(event: event),
    ));

    expect(find.text('Test Trip'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Nocleg'), findsOneWidget);
    expect(find.text('Atrakcje'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Czat'), findsOneWidget);

    expect(find.text('Początek trasy'), findsOneWidget);
    expect(find.text('Koniec trasy'), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Wybierz datę'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Liczba osób'), findsNothing);
  });

  testWidgets('EventDetailsScreen has inputs for Accommodation tab', (WidgetTester tester) async {
    final event = {
      'id': 1,
      'title': 'Test Trip',
      'destination_city': 'Paris',
      'destination_country': 'France',
    };

    await tester.pumpWidget(MaterialApp(
      home: EventDetailsScreen(event: event),
    ));

    await tester.tap(find.text('Nocleg'));
    await tester.pumpAndSettle();

    expect(find.text('Gdzie'), findsOneWidget);
    expect(find.text('Termin pobytu (od - do)'), findsOneWidget);
    expect(find.text('Wybierz od kiedy do kiedy'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Liczba osób'), findsOneWidget);
  });

  testWidgets('EventDetailsScreen has inputs for Attractions tab', (WidgetTester tester) async {
    final event = {
      'id': 1,
      'title': 'Test Trip',
      'destination_city': 'Paris',
      'destination_country': 'France',
    };

    await tester.pumpWidget(MaterialApp(
      home: EventDetailsScreen(event: event),
    ));

    await tester.tap(find.text('Atrakcje'));
    await tester.pumpAndSettle();

    expect(find.text('Miasto/miejsce'), findsOneWidget);
  });
}
