import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_together/models/transport_search_models.dart';
import 'package:trip_together/screens/event_details_screen.dart';
import 'package:trip_together/services/api_exception.dart';
import 'package:trip_together/services/transport_api.dart';

class FakeTransportApi implements ITransportApi {
  FakeTransportApi(this._handler);

  Future<TransportSearchResult> Function({
    required String from,
    required String to,
    String? date,
    String? time,
  }) _handler;

  int calls = 0;

  set handler(
    Future<TransportSearchResult> Function({
      required String from,
      required String to,
      String? date,
      String? time,
    }) value,
  ) {
    _handler = value;
  }

  @override
  void cancelOngoing() {}

  @override
  Future<TransportSearchResult> searchTransport({
    required String from,
    required String to,
    String? date,
    String? time,
  }) {
    calls += 1;
    return _handler(from: from, to: to, date: date, time: time);
  }
}

TransportSearchResult _successResult() {
  return const TransportSearchResult(
    meta: TransportMeta(
      from: 'Warszawa Centralna',
      to: 'Kraków Główny',
      date: '2026-07-01',
      count: 1,
    ),
    results: [
      Journey(
        summary: 'Pociąg',
        icon: 'train',
        durationMinutes: 150,
        durationText: '2 h 30 min',
        transfers: 1,
        departure: '08:10',
        arrival: '10:40',
        fromName: 'Warszawa Centralna',
        toName: 'Kraków Główny',
        legs: [
          JourneyLeg(
            mode: 'WALK',
            modeLabel: 'Pieszo',
            icon: 'walk',
            line: null,
            headsign: null,
            agency: null,
            fromName: 'Start',
            toName: 'Warszawa Centralna',
            departure: '08:00',
            arrival: '08:10',
            durationText: '10 min',
            stops: 0,
            distanceKm: 0.8,
            departureTrack: null,
            arrivalTrack: null,
            realTime: false,
          ),
          JourneyLeg(
            mode: 'RAIL',
            modeLabel: 'Pociąg',
            icon: 'train',
            line: 'IC 1234',
            headsign: 'Kraków Główny',
            agency: 'PKP Intercity',
            fromName: 'Warszawa Centralna',
            toName: 'Kraków Główny',
            departure: '08:10',
            arrival: '10:40',
            durationText: '2 h 30 min',
            stops: 3,
            distanceKm: null,
            departureTrack: '4',
            arrivalTrack: '2',
            realTime: true,
          ),
        ],
      ),
    ],
  );
}

TransportSearchResult _emptyResult() {
  return const TransportSearchResult(
    meta: TransportMeta(from: 'A', to: 'B', date: null, count: 0),
    results: [],
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Future<void> _fillForm(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('transportSearch_from')), 'Warszawa');
  await tester.enterText(find.byKey(const Key('transportSearch_to')), 'Kraków');
  await tester.tap(find.byKey(const Key('transportSearch_submit')));
}

void main() {
  testWidgets('TransportSearchView shows loading then journeys', (tester) async {
    final completer = Completer<TransportSearchResult>();
    final api = FakeTransportApi(({
      required String from,
      required String to,
      String? date,
      String? time,
    }) {
      return completer.future;
    });

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(TransportSearchView(transportApi: api)));

    expect(find.bySemanticsLabel('Transport search from input'), findsOneWidget);
    expect(find.bySemanticsLabel('Transport search submit button'), findsOneWidget);

    await _fillForm(tester);
    await tester.pump();

    expect(find.bySemanticsLabel('Transport loading'), findsOneWidget);
    expect(api.calls, 1);

    completer.complete(_successResult());
    await tester.pumpAndSettle();

    expect(find.text('Pociąg'), findsOneWidget);
    expect(find.textContaining('1 przesiadka'), findsOneWidget);
    expect(find.bySemanticsLabel('Transport result item'), findsWidgets);

    semantics.dispose();
  });

  testWidgets('TransportSearchView expands to show legs', (tester) async {
    final api = FakeTransportApi(({
      required String from,
      required String to,
      String? date,
      String? time,
    }) async {
      return _successResult();
    });

    await tester.pumpWidget(_wrap(TransportSearchView(transportApi: api)));

    await _fillForm(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pociąg'));
    await tester.pumpAndSettle();

    expect(find.textContaining('IC 1234'), findsOneWidget);
    expect(find.textContaining('Warszawa Centralna'), findsWidgets);
  });

  testWidgets('TransportSearchView shows empty state', (tester) async {
    final api = FakeTransportApi(({
      required String from,
      required String to,
      String? date,
      String? time,
    }) async {
      return _emptyResult();
    });

    await tester.pumpWidget(_wrap(TransportSearchView(transportApi: api)));

    await _fillForm(tester);
    await tester.pumpAndSettle();

    expect(find.text('Nie znaleziono połączeń transportu publicznego'), findsOneWidget);
  });

  testWidgets('TransportSearchView validates empty fields', (tester) async {
    final api = FakeTransportApi(({
      required String from,
      required String to,
      String? date,
      String? time,
    }) async {
      return _successResult();
    });

    await tester.pumpWidget(_wrap(TransportSearchView(transportApi: api)));

    await tester.tap(find.byKey(const Key('transportSearch_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Podaj początek trasy.'), findsOneWidget);
    expect(find.text('Podaj koniec trasy.'), findsOneWidget);
    expect(api.calls, 0);
  });

  testWidgets('TransportSearchView shows snackbar with retry on error', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final api = FakeTransportApi(({
      required String from,
      required String to,
      String? date,
      String? time,
    }) async {
      throw ApiException.provider(statusCode: 502);
    });

    await tester.pumpWidget(_wrap(TransportSearchView(transportApi: api)));

    await _fillForm(tester);
    await tester.pumpAndSettle();

    expect(find.text('Ponów'), findsOneWidget);
    expect(api.calls, 1);

    api.handler = ({
      required String from,
      required String to,
      String? date,
      String? time,
    }) async {
      return _successResult();
    };

    final retry = find.text('Ponów');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(api.calls, 2);
    expect(find.text('Pociąg'), findsOneWidget);
  });
}
