from django.contrib.auth import authenticate
from rest_framework.authtoken.models import Token
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status, generics, permissions
import requests
from django.conf import settings

from .models import Event, User, Membership, Invitation, ItineraryItem, ChatMessage, Poll, PollOption, Vote, Notification
from .serializers import (
    EventSerializer, UserRegistrationSerializer, ItineraryItemSerializer,
    ChatMessageSerializer, PollSerializer, PollOptionSerializer, NotificationSerializer,
)

# 1. AUTH & USERS
class RegistrationView(generics.CreateAPIView):
    serializer_class = UserRegistrationSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        data = {
            "id": user.id,
            "email": user.email,
            "username": user.username,
        }
        return Response(data, status=status.HTTP_201_CREATED)

@api_view(['POST'])
def register_user(request):
    serializer = UserRegistrationSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.save()
        data = {"id": user.id, "email": user.email, "username": user.username}
        return Response(data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
def login_user(request):
    email = request.data.get('email', '')
    password = request.data.get('password', '')
    user = authenticate(request, username=email, password=password)
    if user is None:
        return Response({"detail": "Invalid credentials."}, status=status.HTTP_401_UNAUTHORIZED)
    token, _ = Token.objects.get_or_create(user=user)
    return Response({
        "token": token.key,
        "user": {"id": user.id, "email": user.email, "username": user.username},
    }, status=status.HTTP_200_OK)

@api_view(['GET', 'PUT'])
def user_profile(request):
    # Require authentication to view or update profile
    if not request.user or not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)

    if request.method == 'GET':
        user = request.user
        return Response({"id": user.id, "email": user.email, "username": user.username}, status=status.HTTP_200_OK)
    # For PUT: here we just return a success message (update logic not implemented)
    return Response({"message": "Profile updated"}, status=status.HTTP_200_OK)


def _notify_event_members(event, notification_type, title, message, actor=None, poll=None, exclude_actor=True):
    recipients = Membership.objects.filter(event=event).select_related('user')
    if exclude_actor and actor is not None:
        recipients = recipients.exclude(user=actor)

    notifications = [
        Notification(
            recipient=membership.user,
            event=event,
            poll=poll,
            actor=actor,
            notification_type=notification_type,
            title=title,
            message=message,
        )
        for membership in recipients
    ]
    if notifications:
        Notification.objects.bulk_create(notifications)


def _get_event_with_member_access(request, event_id):
    try:
        event = Event.objects.get(pk=event_id)
    except (Event.DoesNotExist, ValueError):
        return None, Response({"detail": "Event not found."}, status=status.HTTP_404_NOT_FOUND)

    if not request.user or not request.user.is_authenticated:
        return None, Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)

    membership = Membership.objects.filter(user=request.user, event=event).first()
    if not membership:
        return None, Response({"detail": "Not authorized for this event."}, status=status.HTTP_403_FORBIDDEN)

    return event, membership

# 2. EVENTS
@api_view(['GET', 'POST'])
def event_list_create(request):
    if not request.user or not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)

    if request.method == 'POST':
        serializer = EventSerializer(data=request.data)
        if serializer.is_valid():
            event = serializer.save(created_by=request.user)
            Membership.objects.create(user=request.user, event=event, role=Membership.Role.OWNER)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    events = Event.objects.filter(memberships__user=request.user)
    serializer = EventSerializer(events, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(['GET', 'PUT'])
def event_detail_update(request, event_id):
    event, membership_or_error = _get_event_with_member_access(request, event_id)
    if event is None:
        return membership_or_error

    if request.method == 'GET':
        return Response(EventSerializer(event).data, status=status.HTTP_200_OK)

    if membership_or_error.role not in (Membership.Role.OWNER, Membership.Role.ADMIN):
        return Response({"detail": "Only event owners or admins can update the event."}, status=status.HTTP_403_FORBIDDEN)

    serializer = EventSerializer(event, data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)

    changed_fields = [field for field, value in serializer.validated_data.items() if getattr(event, field) != value]
    updated_event = serializer.save()

    if changed_fields:
        _notify_event_members(
            updated_event,
            Notification.NotificationType.EVENT_UPDATED,
            title=f'Wydarzenie "{updated_event.title}" zostało zaktualizowane',
            message='Zmienione pola: ' + ', '.join(changed_fields),
            actor=request.user,
        )

    return Response(EventSerializer(updated_event).data, status=status.HTTP_200_OK)

# 3. INVITATIONS
@api_view(['POST'])
def generate_invitation(request, event_id):
    if not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
    try:
        event = Event.objects.get(pk=event_id)
    except (Event.DoesNotExist, ValueError):
        return Response({"detail": "Event not found."}, status=status.HTTP_404_NOT_FOUND)
    if not Membership.objects.filter(user=request.user, event=event).exists():
        return Response({"detail": "Not a member of this event."}, status=status.HTTP_403_FORBIDDEN)
    invitation = Invitation.objects.create(event=event, inviter=request.user)
    return Response({"token": str(invitation.token), "expires_at": invitation.expires_at}, status=status.HTTP_201_CREATED)

@api_view(['GET'])
def invitation_preview(request, token):
    try:
        inv = Invitation.objects.select_related('event', 'inviter').get(token=token)
    except (Invitation.DoesNotExist, ValueError):
        return Response({"detail": "Invalid invitation token."}, status=status.HTTP_404_NOT_FOUND)
    if not inv.is_valid():
        return Response({"detail": "Invitation has expired."}, status=status.HTTP_410_GONE)
    event = inv.event
    return Response({
        "event": {
            "id": event.id,
            "title": event.title,
            "destination_city": event.destination_city,
            "destination_country": event.destination_country,
            "start_date": event.start_date,
            "end_date": event.end_date,
            "member_count": event.memberships.count(),
        },
        "inviter": inv.inviter.username,
        "expires_at": inv.expires_at,
    }, status=status.HTTP_200_OK)

@api_view(['POST'])
def join_event(request, token):
    if not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
    try:
        inv = Invitation.objects.select_related('event', 'inviter').get(token=token)
    except (Invitation.DoesNotExist, ValueError):
        return Response({"detail": "Invalid invitation token."}, status=status.HTTP_404_NOT_FOUND)
    if not inv.is_valid():
        return Response({"detail": "Invitation has expired."}, status=status.HTTP_410_GONE)
    if Membership.objects.filter(user=request.user, event=inv.event).exists():
        return Response({"detail": "Already a member of this event."}, status=status.HTTP_409_CONFLICT)
    Membership.objects.create(
        user=request.user,
        event=inv.event,
        role=Membership.Role.MEMBER,
        invited_by=inv.inviter,
    )
    return Response({"message": "Joined successfully."}, status=status.HTTP_201_CREATED)

# 5. ITINERARY
@api_view(['GET', 'POST'])
def itinerary_list_create(request, event_id):
    try:
        event = Event.objects.get(pk=event_id)
    except (Event.DoesNotExist, ValueError):
        return Response({"detail": "Event not found."}, status=status.HTTP_404_NOT_FOUND)

    if not request.user.is_authenticated or not Membership.objects.filter(user=request.user, event=event).exists():
        return Response({"detail": "Not authorized to view or edit this itinerary."}, status=status.HTTP_403_FORBIDDEN)

    if request.method == 'POST':
        serializer = ItineraryItemSerializer(data=request.data)
        if serializer.is_valid():
            title = serializer.validated_data.get('title')
            
            if ItineraryItem.objects.filter(event=event, title=title).exists():
                return Response({"detail": "Ta atrakcja znajduje się już w planie podróży."}, status=status.HTTP_400_BAD_REQUEST)
                
            serializer.save(event=event, created_by=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    items = ItineraryItem.objects.filter(event=event).order_by('created_at')
    serializer = ItineraryItemSerializer(items, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['DELETE'])
def itinerary_delete(request, event_id, item_id):
    if not request.user or not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)

    try:
        item = ItineraryItem.objects.get(pk=item_id, event_id=event_id)
        if not Membership.objects.filter(user=request.user, event_id=event_id).exists():
            return Response({"detail": "Not authorized to delete from this itinerary."}, status=status.HTTP_403_FORBIDDEN)
        item.delete()
        return Response({"message": "Item deleted"}, status=status.HTTP_204_NO_CONTENT)
    except (ItineraryItem.DoesNotExist, ValueError):
        return Response({"detail": "Item not found."}, status=status.HTTP_404_NOT_FOUND)

@api_view(['GET'])
def search_attractions(request):
    if not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
        
    city = request.query_params.get('city')
    if not city:
        return Response({"detail": "City parameter is required."}, status=status.HTTP_400_BAD_REQUEST)
        
        
    api_key = "88dbcf3ec9msh36cfb22bd814421p1ffb03jsn45e806537050"
     
    headers = {
        "X-RapidAPI-Key": api_key,
        "X-RapidAPI-Host": "opentripmap-places-v1.p.rapidapi.com"
    }

    # Uzyskanie koordynatów
    geo_url = "https://opentripmap-places-v1.p.rapidapi.com/en/places/geoname"
    geo_resp = requests.get(geo_url, headers=headers, params={"name": city})
    
    if geo_resp.status_code != 200 or 'lat' not in geo_resp.json():
        return Response({"detail": "City not found or API error."}, status=status.HTTP_404_NOT_FOUND)
        
    geo_data = geo_resp.json()
    lat, lon = geo_data['lat'], geo_data['lon']

    # Szukanie atrakcji na ich podstawie
    places_url = "https://opentripmap-places-v1.p.rapidapi.com/en/places/radius"
    places_querystring = {
        "radius": "10000", 
        "lon": str(lon), 
        "lat": str(lat), 
        "kinds": "cultural,historic,architecture,natural,amusements",
        "rate": "2", # 2 oznacza średnią i wysoką popularność
        "limit": "30" # limit
    }
    places_resp = requests.get(places_url, headers=headers, params=places_querystring)

    
    if places_resp.status_code != 200:
        error_msg = places_resp.text
        return Response({"detail": f"Error fetching attractions API: {error_msg}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
    features = places_resp.json().get('features', [])
    attractions = []
    
    for f in features:
        props = f.get('properties', {})
        geom = f.get('geometry', {}).get('coordinates', [None, None])
        
        name = props.get('name')
        if not name:
            continue
            
        kinds = props.get('kinds', '')
        
        excluded_keywords = ['hotel', 'accommodation', 'hostel', 'motel', 'guest_house', 'resort', 'apartments']
        if any(keyword in kinds.lower() for keyword in excluded_keywords):
            continue
            
        attractions.append({"name": name, "kinds": kinds, "lat": geom[1] if len(geom) > 1 else None, "lon": geom[0] if len(geom) > 0 else None})
        
    return Response(attractions, status=status.HTTP_200_OK)
# 6. POLLS
def _get_event_for_member(request, event_id):
    """Return (event, error_response). error_response is None when access is allowed."""
    try:
        event = Event.objects.get(pk=event_id)
    except (Event.DoesNotExist, ValueError):
        return None, Response({"detail": "Event not found."}, status=status.HTTP_404_NOT_FOUND)
    if not request.user.is_authenticated or not Membership.objects.filter(user=request.user, event=event).exists():
        return None, Response({"detail": "Not authorized for this event."}, status=status.HTTP_403_FORBIDDEN)
    return event, None


def _coerce_float(value):
    try:
        return float(value) if value is not None and value != '' else None
    except (TypeError, ValueError):
        return None


def _create_option_from_payload(poll, raw, user):
    """Create a PollOption from either a plain string or a rich dict (API item)."""
    if isinstance(raw, dict):
        text = str(raw.get('text') or '').strip()
        if not text:
            return None
        return PollOption.objects.create(
            poll=poll,
            text=text[:255],
            item_type=(raw.get('item_type') or PollOption.ItemType.OTHER),
            description=(raw.get('description') or '').strip(),
            location_lat=_coerce_float(raw.get('location_lat')),
            location_lon=_coerce_float(raw.get('location_lon')),
            created_by=user,
        )
    text = str(raw).strip()
    if not text:
        return None
    return PollOption.objects.create(poll=poll, text=text[:255], created_by=user)


@api_view(['GET', 'POST'])
def poll_list_create(request, event_id):
    event, error = _get_event_for_member(request, event_id)
    if error:
        return error

    if request.method == 'POST':
        question = (request.data.get('question') or '').strip()
        if not question:
            return Response({"detail": "Pytanie ankiety jest wymagane."}, status=status.HTTP_400_BAD_REQUEST)
        poll = Poll.objects.create(event=event, question=question, created_by=request.user)
        for raw in request.data.get('options', []) or []:
            _create_option_from_payload(poll, raw, request.user)
        _notify_event_members(
            event,
            Notification.NotificationType.POLL_CREATED,
            title=f'Nowa ankieta w wydarzeniu "{event.title}"',
            message=question,
            actor=request.user,
            poll=poll,
        )
        return Response(PollSerializer(poll, context={'request': request}).data, status=status.HTTP_201_CREATED)

    polls = (
        event.polls
        .select_related('created_by')
        .prefetch_related('options__votes')
    )
    return Response(PollSerializer(polls, many=True, context={'request': request}).data, status=status.HTTP_200_OK)


@api_view(['POST'])
def poll_option_create(request, event_id, poll_id):
    event, error = _get_event_for_member(request, event_id)
    if error:
        return error
    try:
        poll = Poll.objects.get(pk=poll_id, event=event)
    except (Poll.DoesNotExist, ValueError):
        return Response({"detail": "Poll not found."}, status=status.HTTP_404_NOT_FOUND)
    if poll.is_closed:
        return Response({"detail": "Ankieta jest zamknięta."}, status=status.HTTP_400_BAD_REQUEST)

    text = (request.data.get('text') or '').strip()
    if not text:
        return Response({"detail": "Treść propozycji jest wymagana."}, status=status.HTTP_400_BAD_REQUEST)
    option = _create_option_from_payload(poll, request.data, request.user)
    _notify_event_members(
        event,
        Notification.NotificationType.POLL_OPTION_ADDED,
        title=f'Nowa propozycja do ankiety "{poll.question}"',
        message=text,
        actor=request.user,
        poll=poll,
    )
    return Response(PollOptionSerializer(option, context={'request': request}).data, status=status.HTTP_201_CREATED)


@api_view(['POST'])
def poll_vote(request, event_id, poll_id):
    event, error = _get_event_for_member(request, event_id)
    if error:
        return error
    try:
        poll = Poll.objects.get(pk=poll_id, event=event)
    except (Poll.DoesNotExist, ValueError):
        return Response({"detail": "Poll not found."}, status=status.HTTP_404_NOT_FOUND)
    if poll.is_closed:
        return Response({"detail": "Ankieta jest zamknięta."}, status=status.HTTP_400_BAD_REQUEST)

    option_id = request.data.get('option_id') or request.data.get('option')
    try:
        option = PollOption.objects.get(pk=option_id, poll=poll)
    except (PollOption.DoesNotExist, ValueError, TypeError):
        return Response({"detail": "Nieprawidłowa opcja."}, status=status.HTTP_400_BAD_REQUEST)

    # One vote per user per poll; voting again changes the choice.
    Vote.objects.update_or_create(poll=poll, user=request.user, defaults={'option': option})
    return Response(PollSerializer(poll, context={'request': request}).data, status=status.HTTP_200_OK)


@api_view(['PUT'])
def poll_close(request, event_id, poll_id):
    event, error = _get_event_for_member(request, event_id)
    if error:
        return error
    try:
        poll = Poll.objects.get(pk=poll_id, event=event)
    except (Poll.DoesNotExist, ValueError):
        return Response({"detail": "Poll not found."}, status=status.HTTP_404_NOT_FOUND)

    membership = Membership.objects.filter(user=request.user, event=event).first()
    is_privileged = membership and membership.role in (Membership.Role.OWNER, Membership.Role.ADMIN)
    if poll.created_by_id != request.user.id and not is_privileged:
        return Response({"detail": "Tylko autor ankiety lub organizator może ją zamknąć."}, status=status.HTTP_403_FORBIDDEN)

    poll.is_closed = True
    poll.save(update_fields=['is_closed'])
    _notify_event_members(
        event,
        Notification.NotificationType.POLL_CLOSED,
        title=f'Ankieta "{poll.question}" została zamknięta',
        message='Głosowanie zostało zakończone.',
        actor=request.user,
        poll=poll,
    )
    return Response(PollSerializer(poll, context={'request': request}).data, status=status.HTTP_200_OK)


@api_view(['GET'])
def notification_list(request):
    if not request.user or not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
    notifications = request.user.notifications.select_related('event', 'poll', 'actor')
    return Response(NotificationSerializer(notifications, many=True).data, status=status.HTTP_200_OK)


@api_view(['PUT'])
def notification_mark_read(request, notification_id):
    if not request.user or not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
    try:
        notification = Notification.objects.select_related('event', 'poll', 'actor').get(pk=notification_id, recipient=request.user)
    except Notification.DoesNotExist:
        return Response({"detail": "Notification not found."}, status=status.HTTP_404_NOT_FOUND)
    notification.mark_as_read()
    return Response(NotificationSerializer(notification).data, status=status.HTTP_200_OK)

# 7. CHAT
@api_view(['GET', 'POST'])
def chat_messages(request, event_id):
    try:
        event = Event.objects.get(pk=event_id)
    except (Event.DoesNotExist, ValueError):
        return Response({"detail": "Event not found."}, status=status.HTTP_404_NOT_FOUND)

    if not request.user.is_authenticated or not Membership.objects.filter(user=request.user, event=event).exists():
        return Response({"detail": "Not authorized to view or post in this chat."}, status=status.HTTP_403_FORBIDDEN)

    if request.method == 'POST':
        serializer = ChatMessageSerializer(data=request.data)
        if serializer.is_valid():
            message = serializer.save(event=event, sender=request.user)
            return Response(ChatMessageSerializer(message).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    messages = ChatMessage.objects.filter(event=event).select_related('sender').order_by('created_at')
    serializer = ChatMessageSerializer(messages, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)
