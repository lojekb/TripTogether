from django.test import TestCase
from django.contrib.auth import get_user_model
from django.db import IntegrityError
import datetime

from rest_framework.test import APITestCase
from rest_framework import status

class AllApiTests(APITestCase):
    def test_users(self):
        register_data = {
            "email": "test_register@example.com",
            "username": "test_register",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
        }
        response = self.client.post('/api/v1/auth/register/', register_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        # login and profile endpoints still mocked - profile now requires auth, so authenticate client
        User = get_user_model()
        user = User.objects.get(email='test_register@example.com')
        self.client.force_authenticate(user=user)
        self.assertEqual(self.client.post('/api/v1/auth/login/', {'email': 'test_register@example.com', 'password': 'StrongPass123!'}, format='json').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.get('/api/v1/users/me/').status_code, status.HTTP_200_OK)

    def test_events_and_invites(self):
        # Tworzymy użytkownika na potrzeby autoryzacji/przypisania
        User = get_user_model()
        user = User.objects.create_user(email='test_all_api@example.com', username='test', password='password123')
        # authenticate client for endpoints that require auth
        self.client.force_authenticate(user=user)

        self.assertEqual(self.client.get('/api/v1/events/').status_code, status.HTTP_200_OK)
        
        event_data = {
            "title": "Wycieczka Testowa",
            "destination_city": "Kraków",
            "destination_country": "Polska",
            "start_date": "2024-12-01",
            "end_date": "2024-12-05",
        }
        self.assertEqual(self.client.post('/api/v1/events/', event_data, format='json').status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.get('/api/v1/events/e-1/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.post('/api/v1/events/e-1/invitations/').status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.post('/api/v1/invitations/t-1/join/').status_code, status.HTTP_200_OK)

    def test_itinerary(self):
        # create and authenticate a user because POST requires auth
        User = get_user_model()
        user = User.objects.create_user(email='it_user@example.com', username='ituser', password='password')
        self.client.force_authenticate(user=user)

        self.assertEqual(self.client.get('/api/v1/events/e-1/itinerary/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.post('/api/v1/events/e-1/itinerary/').status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.delete('/api/v1/events/e-1/itinerary/i-1/').status_code, status.HTTP_204_NO_CONTENT)

    def test_polls_and_chat(self):
        # authenticate because poll endpoints require auth
        User = get_user_model()
        user = User.objects.create_user(email='poll_user@example.com', username='poller', password='password')
        self.client.force_authenticate(user=user)

        self.assertEqual(self.client.post('/api/v1/events/e-1/polls/').status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.post('/api/v1/events/e-1/polls/p-1/options/').status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.post('/api/v1/events/e-1/polls/p-1/vote/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.put('/api/v1/events/e-1/polls/p-1/close/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.get('/api/v1/events/e-1/messages/').status_code, status.HTTP_200_OK)


User = get_user_model()


class UserModelTests(TestCase):
    def test_create_user_with_email_and_password(self):
        user = User.objects.create_user(email='alice@example.com', password='secret123', username='alice')
        self.assertEqual(user.email, 'alice@example.com')
        self.assertTrue(user.check_password('secret123'))

    def test_email_is_username_field(self):
        self.assertEqual(User.USERNAME_FIELD, 'email')

    def test_email_uniqueness_enforced(self):
        User.objects.create_user(email='bob@example.com', password='x', username='bob')
        with self.assertRaises(IntegrityError):
            User.objects.create_user(email='bob@example.com', password='y', username='bob2')

    def test_optional_fields_default_to_blank(self):
        user = User.objects.create_user(email='c@example.com', password='x', username='c')
        self.assertEqual(user.bio, '')
        self.assertIsNone(user.date_of_birth)
        self.assertEqual(user.phone_number, '')

    def test_created_at_is_set_on_save(self):
        user = User.objects.create_user(email='d@example.com', password='x', username='d')
        self.assertIsNotNone(user.created_at)

    def test_updated_at_changes_on_update(self):
        user = User.objects.create_user(email='e@example.com', password='x', username='e')
        old_ts = user.updated_at
        user.bio = 'changed'
        user.save()
        user.refresh_from_db()
        self.assertGreaterEqual(user.updated_at, old_ts)

    def test_str_returns_email(self):
        user = User.objects.create_user(email='f@example.com', password='x', username='f')
        self.assertEqual(str(user), 'f@example.com')


class EventModelTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email='owner@example.com', password='x', username='owner')

    def test_create_event_with_required_fields(self):
        from api.models import Event
        event = Event.objects.create(
            title='Rome Trip',
            destination_city='Rome',
            destination_country='Italy',
            start_date=datetime.date(2026, 6, 1),
            end_date=datetime.date(2026, 6, 10),
            created_by=self.user,
        )
        self.assertEqual(event.title, 'Rome Trip')

    def test_default_status_is_draft(self):
        from api.models import Event
        event = Event.objects.create(
            title='Paris',
            destination_city='Paris',
            destination_country='France',
            start_date=datetime.date(2026, 7, 1),
            end_date=datetime.date(2026, 7, 5),
            created_by=self.user,
        )
        self.assertEqual(event.status, Event.Status.DRAFT)

    def test_status_choices_are_valid(self):
        from api.models import Event
        for value in ('DRAFT', 'ACTIVE', 'COMPLETED', 'CANCELLED'):
            self.assertIn(value, [c.value for c in Event.Status])

    def test_max_members_is_nullable(self):
        from api.models import Event
        event = Event.objects.create(
            title='Open Trip',
            destination_city='Berlin',
            destination_country='Germany',
            start_date=datetime.date(2026, 8, 1),
            end_date=datetime.date(2026, 8, 3),
            created_by=self.user,
        )
        self.assertIsNone(event.max_members)

    def test_created_at_is_set_automatically(self):
        from api.models import Event
        event = Event.objects.create(
            title='Auto TS',
            destination_city='Madrid',
            destination_country='Spain',
            start_date=datetime.date(2026, 9, 1),
            end_date=datetime.date(2026, 9, 2),
            created_by=self.user,
        )
        self.assertIsNotNone(event.created_at)

    def test_deleting_creator_cascades_to_event(self):
        from api.models import Event
        event = Event.objects.create(
            title='Cascade',
            destination_city='Oslo',
            destination_country='Norway',
            start_date=datetime.date(2026, 10, 1),
            end_date=datetime.date(2026, 10, 2),
            created_by=self.user,
        )
        event_pk = event.pk
        self.user.delete()
        self.assertFalse(Event.objects.filter(pk=event_pk).exists())

    def test_str_returns_title(self):
        from api.models import Event
        event = Event.objects.create(
            title='Named Event',
            destination_city='Athens',
            destination_country='Greece',
            start_date=datetime.date(2026, 5, 1),
            end_date=datetime.date(2026, 5, 7),
            created_by=self.user,
        )
        self.assertEqual(str(event), 'Named Event')


class MembershipModelTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email='owner2@example.com', password='x', username='owner2')
        self.member = User.objects.create_user(email='member@example.com', password='x', username='member')
        from api.models import Event
        self.event = Event.objects.create(
            title='Group Trip',
            destination_city='Lisbon',
            destination_country='Portugal',
            start_date=datetime.date(2026, 6, 1),
            end_date=datetime.date(2026, 6, 5),
            created_by=self.owner,
        )

    def test_create_membership(self):
        from api.models import Membership
        m = Membership.objects.create(user=self.owner, event=self.event, role=Membership.Role.OWNER)
        self.assertEqual(m.role, Membership.Role.OWNER)

    def test_default_role_is_member(self):
        from api.models import Membership
        m = Membership.objects.create(user=self.member, event=self.event)
        self.assertEqual(m.role, Membership.Role.MEMBER)

    def test_unique_together_user_event(self):
        from api.models import Membership
        Membership.objects.create(user=self.member, event=self.event)
        with self.assertRaises(IntegrityError):
            Membership.objects.create(user=self.member, event=self.event)

    def test_invited_by_is_nullable(self):
        from api.models import Membership
        m = Membership.objects.create(user=self.member, event=self.event, invited_by=None)
        self.assertIsNone(m.invited_by)

    def test_invited_by_can_reference_another_user(self):
        from api.models import Membership
        m = Membership.objects.create(user=self.member, event=self.event, invited_by=self.owner)
        self.assertEqual(m.invited_by, self.owner)

    def test_joined_at_is_set_on_create(self):
        from api.models import Membership
        m = Membership.objects.create(user=self.member, event=self.event)
        self.assertIsNotNone(m.joined_at)

    def test_role_choices_are_valid(self):
        from api.models import Membership
        for value in ('OWNER', 'ADMIN', 'MEMBER'):
            self.assertIn(value, [c.value for c in Membership.Role])

    def test_str_representation(self):
        from api.models import Membership
        m = Membership.objects.create(user=self.member, event=self.event, role=Membership.Role.MEMBER)
        self.assertIn('member@example.com', str(m))
        self.assertIn('Group Trip', str(m))


class LoginTokenTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='login_test@example.com', username='loginuser', password='Pass123!'
        )

    def test_login_with_valid_credentials_returns_token(self):
        resp = self.client.post('/api/v1/auth/login/', {'email': 'login_test@example.com', 'password': 'Pass123!'}, format='json')
        self.assertEqual(resp.status_code, 200)
        self.assertIn('token', resp.data)

    def test_login_with_invalid_credentials_returns_401(self):
        resp = self.client.post('/api/v1/auth/login/', {'email': 'login_test@example.com', 'password': 'wrong'}, format='json')
        self.assertEqual(resp.status_code, 401)

    def test_login_response_contains_user_data(self):
        resp = self.client.post('/api/v1/auth/login/', {'email': 'login_test@example.com', 'password': 'Pass123!'}, format='json')
        self.assertEqual(resp.status_code, 200)
        self.assertIn('user', resp.data)
        user_data = resp.data['user']
        self.assertIn('id', user_data)
        self.assertIn('email', user_data)
        self.assertIn('username', user_data)


class EventListAuthTests(APITestCase):
    def setUp(self):
        from api.models import Event, Membership
        self.user_a = User.objects.create_user(email='event_a@x.com', username='usera', password='Pass!')
        self.user_b = User.objects.create_user(email='event_b@x.com', username='userb', password='Pass!')
        self.event = Event.objects.create(
            title='Trip A', destination_city='Kraków', destination_country='Poland',
            start_date='2026-06-01', end_date='2026-06-10', created_by=self.user_a
        )
        Membership.objects.create(user=self.user_a, event=self.event, role=Membership.Role.OWNER)

    def test_get_events_unauthenticated_returns_401(self):
        resp = self.client.get('/api/v1/events/')
        self.assertEqual(resp.status_code, 401)

    def test_get_events_returns_only_events_where_user_is_member(self):
        self.client.force_authenticate(user=self.user_a)
        resp = self.client.get('/api/v1/events/')
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(len(resp.data), 1)
        self.assertEqual(resp.data[0]['title'], 'Trip A')

    def test_get_events_does_not_return_other_users_events(self):
        self.client.force_authenticate(user=self.user_b)
        resp = self.client.get('/api/v1/events/')
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(len(resp.data), 0)


class EventCreateMembershipTests(APITestCase):
    def setUp(self):
        from api.models import Membership
        self.Membership = Membership
        self.user = User.objects.create_user(email='member_test@x.com', username='memberuser', password='Pass!')
        self.client.force_authenticate(user=self.user)

    def test_create_event_creates_owner_membership(self):
        resp = self.client.post('/api/v1/events/', {
            'title': 'New Trip', 'destination_city': 'Gdańsk',
            'destination_country': 'Poland', 'start_date': '2026-07-01', 'end_date': '2026-07-10'
        }, format='json')
        self.assertEqual(resp.status_code, 201)
        event_id = resp.data['id']
        self.assertTrue(self.Membership.objects.filter(user=self.user, event_id=event_id).exists())

    def test_created_membership_has_owner_role(self):
        resp = self.client.post('/api/v1/events/', {
            'title': 'Owner Trip', 'destination_city': 'Wrocław',
            'destination_country': 'Poland', 'start_date': '2026-08-01', 'end_date': '2026-08-05'
        }, format='json')
        self.assertEqual(resp.status_code, 201)
        event_id = resp.data['id']
        m = self.Membership.objects.get(user=self.user, event_id=event_id)
        self.assertEqual(m.role, self.Membership.Role.OWNER)


class InvitationGenerateTests(APITestCase):
    def setUp(self):
        from api.models import Event, Membership
        self.owner = User.objects.create_user(email='inv_owner@x.com', username='invowner', password='Pass!')
        self.outsider = User.objects.create_user(email='inv_out@x.com', username='invout', password='Pass!')
        self.event = Event.objects.create(
            title='Invite Trip', destination_city='Łódź', destination_country='Poland',
            start_date='2026-09-01', end_date='2026-09-05', created_by=self.owner,
        )
        Membership.objects.create(user=self.owner, event=self.event, role=Membership.Role.OWNER)

    def test_generate_requires_auth(self):
        resp = self.client.post(f'/api/v1/events/{self.event.id}/invitations/')
        self.assertEqual(resp.status_code, 401)

    def test_generate_returns_token(self):
        self.client.force_authenticate(user=self.owner)
        resp = self.client.post(f'/api/v1/events/{self.event.id}/invitations/')
        self.assertEqual(resp.status_code, 201)
        self.assertIn('token', resp.data)

    def test_generate_requires_membership(self):
        self.client.force_authenticate(user=self.outsider)
        resp = self.client.post(f'/api/v1/events/{self.event.id}/invitations/')
        self.assertEqual(resp.status_code, 403)

    def test_generate_tokens_are_unique(self):
        self.client.force_authenticate(user=self.owner)
        token_a = self.client.post(f'/api/v1/events/{self.event.id}/invitations/').data['token']
        token_b = self.client.post(f'/api/v1/events/{self.event.id}/invitations/').data['token']
        self.assertNotEqual(token_a, token_b)


class InvitationPreviewTests(APITestCase):
    def setUp(self):
        from api.models import Event, Membership, Invitation
        self.owner = User.objects.create_user(email='prev_owner@x.com', username='prevowner', password='Pass!')
        self.event = Event.objects.create(
            title='Preview Trip', destination_city='Poznań', destination_country='Poland',
            start_date='2026-10-01', end_date='2026-10-05', created_by=self.owner,
        )
        Membership.objects.create(user=self.owner, event=self.event, role=Membership.Role.OWNER)
        self.invitation = Invitation.objects.create(event=self.event, inviter=self.owner)

    def test_preview_valid_token_returns_event_data(self):
        resp = self.client.get(f'/api/v1/invitations/{self.invitation.token}/')
        self.assertEqual(resp.status_code, 200)
        self.assertIn('event', resp.data)
        self.assertEqual(resp.data['event']['title'], 'Preview Trip')
        self.assertIn('inviter', resp.data)

    def test_preview_invalid_token_returns_404(self):
        resp = self.client.get('/api/v1/invitations/00000000-0000-0000-0000-000000000000/')
        self.assertEqual(resp.status_code, 404)

    def test_preview_expired_token_returns_410(self):
        from api.models import Invitation
        from django.utils import timezone
        from datetime import timedelta
        expired = Invitation.objects.create(event=self.event, inviter=self.owner)
        expired.expires_at = timezone.now() - timedelta(hours=1)
        expired.save()
        resp = self.client.get(f'/api/v1/invitations/{expired.token}/')
        self.assertEqual(resp.status_code, 410)


class JoinEventTests(APITestCase):
    def setUp(self):
        from api.models import Event, Membership, Invitation
        self.Membership = Membership
        self.owner = User.objects.create_user(email='join_owner@x.com', username='joinowner', password='Pass!')
        self.joiner = User.objects.create_user(email='join_user@x.com', username='joinuser', password='Pass!')
        self.event = Event.objects.create(
            title='Join Trip', destination_city='Katowice', destination_country='Poland',
            start_date='2026-11-01', end_date='2026-11-05', created_by=self.owner,
        )
        Membership.objects.create(user=self.owner, event=self.event, role=Membership.Role.OWNER)
        self.invitation = Invitation.objects.create(event=self.event, inviter=self.owner)

    def test_join_requires_auth(self):
        resp = self.client.post(f'/api/v1/invitations/{self.invitation.token}/join/')
        self.assertEqual(resp.status_code, 401)

    def test_join_creates_membership(self):
        self.client.force_authenticate(user=self.joiner)
        resp = self.client.post(f'/api/v1/invitations/{self.invitation.token}/join/')
        self.assertEqual(resp.status_code, 201)
        self.assertTrue(self.Membership.objects.filter(user=self.joiner, event=self.event).exists())

    def test_join_sets_member_role(self):
        self.client.force_authenticate(user=self.joiner)
        self.client.post(f'/api/v1/invitations/{self.invitation.token}/join/')
        m = self.Membership.objects.get(user=self.joiner, event=self.event)
        self.assertEqual(m.role, self.Membership.Role.MEMBER)

    def test_join_sets_invited_by(self):
        self.client.force_authenticate(user=self.joiner)
        self.client.post(f'/api/v1/invitations/{self.invitation.token}/join/')
        m = self.Membership.objects.get(user=self.joiner, event=self.event)
        self.assertEqual(m.invited_by, self.owner)

    def test_join_expired_token_returns_410(self):
        from api.models import Invitation
        from django.utils import timezone
        from datetime import timedelta
        expired = Invitation.objects.create(event=self.event, inviter=self.owner)
        expired.expires_at = timezone.now() - timedelta(hours=1)
        expired.save()
        self.client.force_authenticate(user=self.joiner)
        resp = self.client.post(f'/api/v1/invitations/{expired.token}/join/')
        self.assertEqual(resp.status_code, 410)

    def test_join_duplicate_returns_409(self):
        self.client.force_authenticate(user=self.joiner)
        self.client.post(f'/api/v1/invitations/{self.invitation.token}/join/')
        resp = self.client.post(f'/api/v1/invitations/{self.invitation.token}/join/')
        self.assertEqual(resp.status_code, 409)


class EventCreateTests(APITestCase):
    def setUp(self):
        # Tworzymy testowego użytkownika
        self.user = User.objects.create_user(
            email='testuser@example.com',
            username='testuser',
            password='testpassword123'
        )
        # authenticate the test client for endpoints that require auth
        self.client.force_authenticate(user=self.user)
        self.url = '/api/v1/events/'

    def test_create_event_success(self):
        """Test pomyślnego utworzenia wydarzenia z prawidłowymi danymi"""
        from api.models import Event
        data = {
            "title": "Wycieczka w Tatry",
            "destination_city": "Zakopane",
            "destination_country": "Polska",
            "start_date": "2024-08-01",
            "end_date": "2024-08-07",
            "description": "Górskie wędrówki i oscypki",
            "max_members": 5
        }
        response = self.client.post(self.url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(Event.objects.filter(title="Wycieczka w Tatry").exists())

    def test_create_event_invalid_dates(self):
        """Test walidacji: data startowa późniejsza niż końcowa"""
        data = {
            "title": "Błędne daty",
            "destination_city": "Zakopane",
            "destination_country": "Polska",
            "start_date": "2024-08-10",
            "end_date": "2024-08-01",  # Błąd!
        }
        response = self.client.post(self.url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('end_date', response.data) 

    def test_create_event_missing_required_fields(self):
        """Test walidacji: brak wymaganych pól, takich jak miasto"""
        data = {"title": "Tylko Tytuł"}
        response = self.client.post(self.url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('destination_city', response.data)
        self.assertIn('start_date', response.data)

