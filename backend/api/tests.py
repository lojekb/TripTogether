from rest_framework.test import APITestCase
from rest_framework import status


class AuthTests(APITestCase):
    def test_register_and_login(self):
        res = self.client.post('/api/auth/register/', {"email": "a@a.com", "password": "123"}, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        res2 = self.client.post('/api/auth/login/', {"email": "a@a.com", "password": "123"}, format='json')
        self.assertEqual(res2.status_code, status.HTTP_200_OK)

    def test_profile(self):
        res = self.client.get('/api/users/me/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)


class EventAndMembershipTests(APITestCase):
    def test_events_crud(self):
        self.assertEqual(self.client.get('/api/events/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.post('/api/events/', {"title": "Wyjazd"}, format='json').status_code,
                         status.HTTP_201_CREATED)
        self.assertEqual(self.client.get('/api/events/evt-1/').status_code, status.HTTP_200_OK)

    def test_invitations(self):
        self.assertEqual(self.client.post('/api/events/evt-1/invitations/').status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.post('/api/invitations/token-123/join/').status_code, status.HTTP_200_OK)


class ItineraryAndChatTests(APITestCase):
    def test_itinerary(self):
        self.assertEqual(self.client.get('/api/events/evt-1/itinerary/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.post('/api/events/evt-1/itinerary/', {"type": "HOTEL"}, format='json').status_code,
                         status.HTTP_201_CREATED)
        self.assertEqual(self.client.delete('/api/events/evt-1/itinerary/item-1/').status_code,
                         status.HTTP_204_NO_CONTENT)

    def test_chat(self):
        self.assertEqual(self.client.get('/api/events/evt-1/messages/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.post('/api/events/evt-1/messages/', {"text": "Hej"}, format='json').status_code,
                         status.HTTP_201_CREATED)


class PollsTests(APITestCase):
    def test_polls_flow(self):
        self.assertEqual(self.client.post('/api/events/evt-1/polls/').status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.post('/api/events/evt-1/polls/poll-1/options/').status_code,
                         status.HTTP_201_CREATED)
        self.assertEqual(
            self.client.post('/api/events/evt-1/polls/poll-1/vote/', {"pollOptionId": "opt-1", "value": "UP"},
                             format='json').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.put('/api/events/evt-1/polls/poll-1/close/').status_code, status.HTTP_200_OK)


from django.test import TestCase

# Create your tests here.
