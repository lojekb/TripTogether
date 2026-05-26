import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_together/models/hotel_search_models.dart';
import 'package:trip_together/screens/event_details_screen.dart';
import 'package:trip_together/services/api_exception.dart';
import 'package:trip_together/services/hotel_api.dart';

class FakeHotelApi implements IHotelApi {
  FakeHotelApi(this._handler);

  Future<HotelSearchResult> Function({
    required String q,
    String? checkIn,
    String? checkOut,
    int adults,
    int limit,
  }) _handler;

  int calls = 0;

  set handler(
    Future<HotelSearchResult> Function({
      required String q,
      String? checkIn,
      String? checkOut,
      int adults,
      int limit,
    }) value,
  ) {
    _handler = value;
  }

  @override
  void cancelOngoing() {}

  @override
  Future<HotelSearchResult> searchHotels({
    required String q,
    String? checkIn,
    String? checkOut,
    int adults = 1,
    int limit = 15,
  }) {
    calls += 1;
    return _handler(q: q, checkIn: checkIn, checkOut: checkOut, adults: adults, limit: limit);
  }
}

HotelSearchResult _successResult() {
  return HotelSearchResult(
    meta: const Meta(
      location: 'Western Poland, Poland',
      checkIn: '2026-06-01',
      checkOut: '2026-06-04',
      nights: 3,
      adults: 2,
      count: 1,
    ),
    results: const [
      Hotel(
        key: 'k1',
        name: 'Test Hotel',
        accommodationType: 'Hotel',
        review: Review(rating: 4.5, count: 10),
        mentions: [],
        merchandisingLabels: [],
        priceRanges: PriceRanges(minimum: 71, maximum: 106),
        url: 'https://example.com/hotel',
        rates: [
          Rate(
            code: 'BookingCom',
            name: 'Booking.com',
            rate: 67,
            tax: 5,
            perNight: 67,
            totalForStay: 201,
          ),
          Rate(
            code: 'Direct',
            name: 'Direct',
            rate: 80,
            tax: 10,
            perNight: 80,
            totalForStay: 240,
          ),
        ],
      ),
    ],
  );
}

HotelSearchResult _emptyResult() {
  return const HotelSearchResult(
    meta: Meta(
      location: 'Somewhere',
      checkIn: null,
      checkOut: null,
      nights: null,
      adults: 1,
      count: 0,
    ),
    results: [],
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  testWidgets('AccommodationSearchView shows loading then results', (tester) async {
    final completer = Completer<HotelSearchResult>();
    final api = FakeHotelApi(({
      required String q,
      String? checkIn,
      String? checkOut,
      int adults = 1,
      int limit = 15,
    }) {
      return completer.future;
    });

    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_wrap(AccommodationSearchView(hotelApi: api)));
    

    expect(find.bySemanticsLabel('Hotel search city input'), findsOneWidget);
    expect(find.bySemanticsLabel('Hotel search submit button'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('hotelSearch_city')), 'Szczecin');
    await tester.tap(find.byKey(const Key('hotelSearch_submit')));
    await tester.pump();

    expect(find.bySemanticsLabel('Hotels loading'), findsOneWidget);
    expect(api.calls, 1);

    completer.complete(_successResult());
    await tester.pumpAndSettle();

    expect(find.text('Test Hotel'), findsOneWidget);
    expect(find.textContaining('From'), findsOneWidget);
    expect(find.bySemanticsLabel('Hotel search result item'), findsWidgets);

    semantics.dispose();
  });

  testWidgets('AccommodationSearchView shows empty state', (tester) async {
    final api = FakeHotelApi(({
      required String q,
      String? checkIn,
      String? checkOut,
      int adults = 1,
      int limit = 15,
    }) async {
      return _emptyResult();
    });

    await tester.pumpWidget(_wrap(AccommodationSearchView(hotelApi: api)));

    await tester.enterText(find.byKey(const Key('hotelSearch_city')), 'Szczecin');
    await tester.tap(find.byKey(const Key('hotelSearch_submit')));
    await tester.pumpAndSettle();

    expect(find.text('No hotels found'), findsOneWidget);
  });

  testWidgets('AccommodationSearchView shows snackbar with Retry on error', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final api = FakeHotelApi(({
      required String q,
      String? checkIn,
      String? checkOut,
      int adults = 1,
      int limit = 15,
    }) async {
      throw ApiException.provider(statusCode: 502);
    });

    await tester.pumpWidget(_wrap(AccommodationSearchView(hotelApi: api)));

    await tester.enterText(find.byKey(const Key('hotelSearch_city')), 'Szczecin');
    await tester.tap(find.byKey(const Key('hotelSearch_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(api.calls, 1);

    api.handler = ({
      required String q,
      String? checkIn,
      String? checkOut,
      int adults = 1,
      int limit = 15,
    }) async {
      return _successResult();
    };

    final retry = find.text('Retry');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(api.calls, 2);
    expect(find.text('Test Hotel'), findsOneWidget);
  });
}
