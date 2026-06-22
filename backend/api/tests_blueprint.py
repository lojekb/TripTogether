from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase
from rest_framework import status

from api.models import Event, Membership, ItineraryItem, ChatMessage, Poll, EventBlueprint

User = get_user_model()


class BlueprintGenerateTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email='bp_owner@x.com', username='bpowner', password='Pass!')
        self.member = User.objects.create_user(email='bp_member@x.com', username='bpmember', password='Pass!')
        self.outsider = User.objects.create_user(email='bp_out@x.com', username='bpout', password='Pass!')
        self.event = Event.objects.create(
            title='Blueprint Trip', description='Plan na weekend',
            destination_city='Kraków', destination_country='Poland',
            start_date='2026-06-01', end_date='2026-06-05', created_by=self.owner,
            max_members=6,
        )
        Membership.objects.create(user=self.owner, event=self.event, role=Membership.Role.OWNER)
        Membership.objects.create(user=self.member, event=self.event, role=Membership.Role.MEMBER)
        ItineraryItem.objects.create(event=self.event, title='Wawel', item_type=ItineraryItem.ItemType.ATTRACTION, created_by=self.owner)
        ItineraryItem.objects.create(event=self.event, title='Hotel Stary', item_type=ItineraryItem.ItemType.HOTEL, created_by=self.owner)
        self.url = f'/api/v1/events/{self.event.id}/blueprint/'

    def test_generate_requires_auth(self):
        self.assertEqual(self.client.post(self.url).status_code, status.HTTP_401_UNAUTHORIZED)

    def test_generate_requires_membership(self):
        self.client.force_authenticate(user=self.outsider)
        self.assertEqual(self.client.post(self.url).status_code, status.HTTP_403_FORBIDDEN)

    def test_member_can_generate_and_gets_token(self):
        self.client.force_authenticate(user=self.member)
        resp = self.client.post(self.url)
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertIn('token', resp.data)

    def test_generate_freezes_itinerary_snapshot(self):
        self.client.force_authenticate(user=self.owner)
        token = self.client.post(self.url).data['token']
        blueprint = EventBlueprint.objects.get(token=token)
        self.assertEqual(len(blueprint.itinerary), 2)
        titles = {item['title'] for item in blueprint.itinerary}
        self.assertEqual(titles, {'Wawel', 'Hotel Stary'})

    def test_generate_tokens_are_unique(self):
        self.client.force_authenticate(user=self.owner)
        token_a = self.client.post(self.url).data['token']
        token_b = self.client.post(self.url).data['token']
        self.assertNotEqual(token_a, token_b)


class BlueprintPreviewTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email='bpp_owner@x.com', username='bppowner', password='Pass!')
        self.event = Event.objects.create(
            title='Preview Blueprint', description='Opis',
            destination_city='Gdańsk', destination_country='Poland',
            start_date='2026-07-01', end_date='2026-07-05', created_by=self.owner,
        )
        Membership.objects.create(user=self.owner, event=self.event, role=Membership.Role.OWNER)
        ItineraryItem.objects.create(event=self.event, title='Stare Miasto', created_by=self.owner)
        self.blueprint = EventBlueprint.create_from_event(self.event, self.owner)
        self.url = f'/api/v1/blueprints/{self.blueprint.token}/'

    def test_preview_is_public(self):
        resp = self.client.get(self.url)
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['blueprint']['title'], 'Preview Blueprint')
        self.assertEqual(resp.data['blueprint']['destination_city'], 'Gdańsk')
        self.assertEqual(resp.data['blueprint']['itinerary_count'], 1)
        self.assertEqual(resp.data['created_by'], 'bppowner')

    def test_preview_includes_itinerary_items(self):
        resp = self.client.get(self.url)
        titles = [item['title'] for item in resp.data['blueprint']['itinerary']]
        self.assertIn('Stare Miasto', titles)

    def test_preview_invalid_token_returns_404(self):
        resp = self.client.get('/api/v1/blueprints/00000000-0000-0000-0000-000000000000/')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_preview_survives_source_event_deletion(self):
        self.event.delete()
        resp = self.client.get(self.url)
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['blueprint']['title'], 'Preview Blueprint')


class BlueprintCopyTests(APITestCase):
    def setUp(self):
        self.author = User.objects.create_user(email='bpc_author@x.com', username='bpcauthor', password='Pass!')
        self.copier = User.objects.create_user(email='bpc_copier@x.com', username='bpccopier', password='Pass!')
        self.event = Event.objects.create(
            title='Original Trip', description='Oryginalny opis',
            destination_city='Wrocław', destination_country='Poland',
            start_date='2026-08-01', end_date='2026-08-05', created_by=self.author,
            max_members=4,
        )
        Membership.objects.create(user=self.author, event=self.event, role=Membership.Role.OWNER)
        ItineraryItem.objects.create(event=self.event, title='Rynek', item_type=ItineraryItem.ItemType.ATTRACTION, created_by=self.author)
        ItineraryItem.objects.create(event=self.event, title='Most Tumski', item_type=ItineraryItem.ItemType.ATTRACTION, created_by=self.author)
        ChatMessage.objects.create(event=self.event, sender=self.author, content='Tylko dla oryginału')
        Poll.objects.create(event=self.event, question='Tylko dla oryginału?', created_by=self.author)
        self.blueprint = EventBlueprint.create_from_event(self.event, self.author)
        self.url = f'/api/v1/blueprints/{self.blueprint.token}/copy/'

    def test_copy_requires_auth(self):
        self.assertEqual(self.client.post(self.url).status_code, status.HTTP_401_UNAUTHORIZED)

    def test_copy_creates_new_event_owned_by_copier(self):
        self.client.force_authenticate(user=self.copier)
        resp = self.client.post(self.url)
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        new_id = resp.data['id']
        self.assertNotEqual(new_id, self.event.id)
        new_event = Event.objects.get(pk=new_id)
        self.assertEqual(new_event.created_by, self.copier)
        self.assertEqual(new_event.status, Event.Status.DRAFT)
        membership = Membership.objects.get(user=self.copier, event=new_event)
        self.assertEqual(membership.role, Membership.Role.OWNER)

    def test_copy_duplicates_itinerary(self):
        self.client.force_authenticate(user=self.copier)
        new_id = self.client.post(self.url).data['id']
        items = ItineraryItem.objects.filter(event_id=new_id)
        self.assertEqual(items.count(), 2)
        self.assertEqual({i.title for i in items}, {'Rynek', 'Most Tumski'})

    def test_copy_does_not_duplicate_social_data(self):
        self.client.force_authenticate(user=self.copier)
        new_id = self.client.post(self.url).data['id']
        self.assertEqual(ChatMessage.objects.filter(event_id=new_id).count(), 0)
        self.assertEqual(Poll.objects.filter(event_id=new_id).count(), 0)
        self.assertEqual(Membership.objects.filter(event_id=new_id).count(), 1)

    def test_copy_applies_overrides(self):
        self.client.force_authenticate(user=self.copier)
        resp = self.client.post(self.url, {
            'title': 'Moja własna wersja',
            'start_date': '2027-01-10',
            'end_date': '2027-01-15',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertEqual(resp.data['title'], 'Moja własna wersja')
        self.assertEqual(resp.data['start_date'], '2027-01-10')
        self.assertEqual(resp.data['destination_city'], 'Wrocław')

    def test_copy_defaults_to_snapshot_values(self):
        self.client.force_authenticate(user=self.copier)
        resp = self.client.post(self.url)
        self.assertEqual(resp.data['title'], 'Original Trip')
        self.assertEqual(resp.data['start_date'], '2026-08-01')

    def test_copy_rejects_invalid_dates(self):
        self.client.force_authenticate(user=self.copier)
        resp = self.client.post(self.url, {
            'start_date': '2027-05-10',
            'end_date': '2027-05-01',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_copy_survives_source_event_deletion(self):
        self.event.delete()
        self.client.force_authenticate(user=self.copier)
        resp = self.client.post(self.url)
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertEqual(ItineraryItem.objects.filter(event_id=resp.data['id']).count(), 2)

    def test_copy_invalid_token_returns_404(self):
        self.client.force_authenticate(user=self.copier)
        resp = self.client.post('/api/v1/blueprints/00000000-0000-0000-0000-000000000000/copy/')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)
