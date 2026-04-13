from django.test import TestCase
from rest_framework.test import APIRequestFactory
from rest_framework import status
from .models import Event
from .serializers import EventSerializer
from .views import event_list_create
import datetime

class EventTests(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.valid_data = {
            "title": "Wycieczka do Paryża",
            "city": "Paryż",
            "start_date": "2024-06-01",
            "end_date": "2024-06-10",
            "status": "DRAFT"
        }
        self.invalid_data = {
            "title": "Zła wycieczka",
            "city": "Londyn",
            "start_date": "2024-06-15",
            "end_date": "2024-06-10", # data końcowa przed początkową
            "status": "DRAFT"
        }

    def test_create_event_model_directly(self):
        # Test bezpośredniego tworzenia rekordu w bazie za pomocą modelu
        event = Event.objects.create(
            title="Testowe wydarzenie",
            city="Testowe miasto",
            start_date=datetime.date(2024, 1, 1),
            end_date=datetime.date(2024, 1, 5)
        )
        self.assertEqual(Event.objects.count(), 1)
        self.assertEqual(event.title, "Testowe wydarzenie")

    def test_event_serializer_validation_success(self):
        # Test poprawności walidacji dla prawidłowych danych
        serializer = EventSerializer(data=self.valid_data)
        self.assertTrue(serializer.is_valid(), serializer.errors)

    def test_event_serializer_validation_error(self):
        # Test odrzucenia przez serializer danych ze złą datą
        serializer = EventSerializer(data=self.invalid_data)
        self.assertFalse(serializer.is_valid())
        self.assertIn("end_date", serializer.errors)

    def test_event_list_create_view_post(self):
        # Test całego endpointu (widoku) generując sztuczne zapytanie POST
        request = self.factory.post('/api/events/', self.valid_data, format='json')
        response = event_list_create(request)
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Event.objects.count(), 1)
        self.assertEqual(response.data['city'], "Paryż")