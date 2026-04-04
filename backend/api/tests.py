from rest_framework.test import APITestCase
from rest_framework import status

class AllApiTests(APITestCase):
    def test_users(self):
        self.assertEqual(self.client.post('/api/v1/auth/register/').status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.post('/api/v1/auth/login/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.get('/api/v1/users/me/').status_code, status.HTTP_200_OK)

    def test_events_and_invites(self):
        self.assertEqual(self.client.get('/api/v1/events/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.post('/api/v1/events/').status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.get('/api/v1/events/e-1/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.post('/api/v1/events/e-1/invitations/').status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.post('/api/v1/invitations/t-1/join/').status_code, status.HTTP_200_OK)

    def test_itinerary(self):
        self.assertEqual(self.client.get('/api/v1/events/e-1/itinerary/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.post('/api/v1/events/e-1/itinerary/').status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.delete('/api/v1/events/e-1/itinerary/i-1/').status_code, status.HTTP_204_NO_CONTENT)

    def test_polls_and_chat(self):
        self.assertEqual(self.client.post('/api/v1/events/e-1/polls/').status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.post('/api/v1/events/e-1/polls/p-1/options/').status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.post('/api/v1/events/e-1/polls/p-1/vote/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.put('/api/v1/events/e-1/polls/p-1/close/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.get('/api/v1/events/e-1/messages/').status_code, status.HTTP_200_OK)