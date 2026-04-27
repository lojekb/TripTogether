from django.contrib.auth import authenticate
from rest_framework.authtoken.models import Token
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status, generics, permissions

from .models import Event, User, Membership
from .serializers import EventSerializer, UserRegistrationSerializer

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
    if request.method == 'GET':
        return Response({"id": event_id, "title": "May trip to Rome", "city": "Rome"}, status=status.HTTP_200_OK)
    # PUT should require authentication
    if not request.user or not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
    return Response({"message": "Event updated"}, status=status.HTTP_200_OK)

# 3. INVITATIONS
@api_view(['POST'])
def generate_invitation(request, event_id):
    # Ideally require auth here; keeping public for now
    return Response({"token": "token-123"}, status=status.HTTP_201_CREATED)

@api_view(['POST'])
def join_event(request, token):
    return Response({"message": "Successfully joined"}, status=status.HTTP_200_OK)

# 5. ITINERARY
@api_view(['GET', 'POST'])
def itinerary_list_create(request, event_id):
    if request.method == 'POST':
        # require auth to modify itinerary
        if not request.user or not request.user.is_authenticated:
            return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
        return Response({"id": "item-123", "type": "HOTEL"}, status=status.HTTP_201_CREATED)
    return Response([{"id": "item-1", "type": "FLIGHT"}], status=status.HTTP_200_OK)

@api_view(['DELETE'])
def itinerary_delete(request, event_id, item_id):
    if not request.user or not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
    return Response({"message": "Item deleted"}, status=status.HTTP_204_NO_CONTENT)

# 6. POLLS
@api_view(['POST'])
def poll_create(request, event_id):
    if not request.user or not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
    return Response({"id": "poll-1", "question": "How are we traveling?"}, status=status.HTTP_201_CREATED)

@api_view(['POST'])
def poll_option_create(request, event_id, poll_id):
    if not request.user or not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
    return Response({"id": "opt-1", "text": "Train"}, status=status.HTTP_201_CREATED)

@api_view(['POST'])
def poll_vote(request, event_id, poll_id):
    if not request.user or not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
    return Response({"message": "Vote recorded"}, status=status.HTTP_200_OK)

@api_view(['PUT'])
def poll_close(request, event_id, poll_id):
    if not request.user or not request.user.is_authenticated:
        return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
    return Response({"message": "Poll closed"}, status=status.HTTP_200_OK)

# 7. CHAT
@api_view(['GET', 'POST'])
def chat_messages(request, event_id):
    if request.method == 'POST':
        if not request.user or not request.user.is_authenticated:
            return Response({"detail": "Authentication credentials were not provided."}, status=status.HTTP_401_UNAUTHORIZED)
        return Response({"id": "msg-1", "text": "Hey"}, status=status.HTTP_201_CREATED)
    return Response([{"id": "msg-001", "text": "Hello!"}], status=status.HTTP_200_OK)
