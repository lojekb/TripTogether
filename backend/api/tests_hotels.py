from django.test import TestCase, Client
from unittest.mock import patch


class HotelSearchTests(TestCase):
    def setUp(self):
        self.client = Client()
        self.url = '/api/v1/hotels/search/'

    @patch('api.views_hotels.get_rates')
    @patch('api.views_hotels.get_hotels')
    @patch('api.views_hotels.search_location')
    def test_returns_hotels_with_rates(self, mock_search_location, mock_get_hotels, mock_get_rates):
        mock_search_location.return_value = [{'location_key': 'loc1', 'place_name': 'TestPlace'}]
        mock_get_hotels.return_value = [{'key': 'h1', 'name': 'Hotel1', 'price_ranges': {}, 'review_summary': {}}]
        mock_get_rates.return_value = [{'code': 'BookingCom', 'name': 'Booking.com', 'rate': 100}]

        resp = self.client.get(self.url + '?q=Test&check_in=2026-06-01&check_out=2026-06-04&adults=2&limit=15')
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn('results', data)
        self.assertEqual(len(data['results']), 1)
        self.assertEqual(data['results'][0]['key'], 'h1')
        self.assertTrue(data['results'][0]['rates'])

    @patch('api.views_hotels.search_location')
    def test_no_locations_returns_empty(self, mock_search_location):
        mock_search_location.return_value = []
        resp = self.client.get(self.url + '?q=Nope')
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data.get('results', []), [])
