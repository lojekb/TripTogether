import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_together/services/api_exception.dart';
import 'package:trip_together/services/hotel_api.dart';

void main() {
  test('HotelApi.searchHotels builds request and parses response', () async {
    final sample = {
      'meta': {
        'location': 'Western Poland, Poland',
        'check_in': '2026-06-01',
        'check_out': '2026-06-04',
        'nights': 3,
        'adults': 2,
        'count': 15,
      },
      'results': [
        {
          'key': 'g274736-d24137049',
          'name': 'ibis Styles Szczecin Stare Miasto',
          'accommodation_type': 'Hotel',
          'review': {'rating': 4.7, 'count': 33},
          'mentions': [],
          'merchandising_labels': [],
          'price_ranges': {'minimum': 71, 'maximum': 106},
          'url': 'https://example.com/hotel',
          'rates': [
            {
              'code': 'BookingCom',
              'name': 'Booking.com',
              'rate': 67,
              'tax': 5,
              'per_night': 67,
              'total_for_stay': 201
            },
            {
              'code': 'Direct',
              'name': 'Direct',
              'rate': 80,
              'tax': 10,
              'per_night': 80,
              'total_for_stay': 240
            }
          ]
        }
      ]
    };

    final client = MockClient((http.Request request) async {
      expect(request.method, 'GET');
      expect(request.headers['Accept'], 'application/json');
      expect(request.url.path, '/api/v1/hotels/search/');
      expect(request.url.queryParameters['q'], 'Szczecin');
      expect(request.url.queryParameters['check_in'], '2026-06-01');
      expect(request.url.queryParameters['check_out'], '2026-06-04');
      expect(request.url.queryParameters['adults'], '2');
      expect(request.url.queryParameters['limit'], '15');

      return http.Response(jsonEncode(sample), 200, headers: {'content-type': 'application/json'});
    });

    final api = HotelApi(
      baseUrl: 'https://backend.example',
      httpClient: client,
      timeout: const Duration(seconds: 1),
    );

    final result = await api.searchHotels(
      q: 'Szczecin',
      checkIn: '2026-06-01',
      checkOut: '2026-06-04',
      adults: 2,
      limit: 15,
    );

    expect(result.meta.location, 'Western Poland, Poland');
    expect(result.meta.nights, 3);
    expect(result.results, hasLength(1));
    expect(result.results.first.name, 'ibis Styles Szczecin Stare Miasto');
    expect(result.results.first.review?.rating, closeTo(4.7, 0.001));
    expect(result.results.first.rates, hasLength(2));
    expect(result.results.first.rates.first.perNight, 67.0);
    expect(result.results.first.priceRanges?.minimum, 71.0);
  });

  test('HotelApi.searchHotels throws provider error on 502', () async {
    final client = MockClient((_) async => http.Response('{"detail":"bad gateway"}', 502));

    final api = HotelApi(
      baseUrl: 'https://backend.example',
      httpClient: client,
      timeout: const Duration(seconds: 1),
    );

    await expectLater(
      () => api.searchHotels(q: 'Szczecin'),
      throwsA(
        predicate(
          (e) => e is ApiException && e.kind == ApiExceptionKind.provider && e.statusCode == 502,
        ),
      ),
    );
  });

  test('HotelApi.searchHotels throws timeout', () async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return http.Response('{}', 200);
    });

    final api = HotelApi(
      baseUrl: 'https://backend.example',
      httpClient: client,
      timeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      () => api.searchHotels(q: 'Szczecin'),
      throwsA(
        predicate((e) => e is ApiException && e.kind == ApiExceptionKind.timeout),
      ),
    );
  });
}
