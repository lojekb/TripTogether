from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
import uuid
from .models import Event
from .serializers import EventSerializer

# 1. AUTORYZACJA I UŻYTKOWNICY
@api_view(['POST'])
def register_user(request):
    return Response({"message": "Zarejestrowano", "userId": str(uuid.uuid4())}, status=status.HTTP_201_CREATED)

@api_view(['POST'])
def login_user(request):
    return Response({"token": "mock.jwt.token"}, status=status.HTTP_200_OK)

@api_view(['GET', 'PUT'])
def user_profile(request):
    if request.method == 'GET':
        return Response({"id": "u-1", "name": "Jan", "email": "jan@test.com"}, status=status.HTTP_200_OK)
    return Response({"message": "Zaktualizowano profil"}, status=status.HTTP_200_OK)

# 2. WYDARZENIA
@api_view(['GET', 'POST'])
def event_list_create(request):
    if request.method == 'POST':
        serializer = EventSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    events = Event.objects.all()
    serializer = EventSerializer(events, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET', 'PUT'])
def event_detail_update(request, event_id):
    if request.method == 'GET':
        return Response({"id": event_id, "title": "Majówka w Rzymie", "city": "Rome"}, status=status.HTTP_200_OK)
    return Response({"message": "Zaktualizowano wydarzenie"}, status=status.HTTP_200_OK)

# 3. ZAPROSZENIA
@api_view(['POST'])
def generate_invitation(request, event_id):
    return Response({"token": "token-123"}, status=status.HTTP_201_CREATED)

@api_view(['POST'])
def join_event(request, token):
    return Response({"message": "Dołączono pomyślnie"}, status=status.HTTP_200_OK)

# 5. PLAN PODRÓŻY
@api_view(['GET', 'POST'])
def itinerary_list_create(request, event_id):
    if request.method == 'POST':
        return Response({"id": "item-123", "type": "HOTEL"}, status=status.HTTP_201_CREATED)
    return Response([{"id": "item-1", "type": "FLIGHT"}], status=status.HTTP_200_OK)

@api_view(['DELETE'])
def itinerary_delete(request, event_id, item_id):
    return Response({"message": "Usunięto pozycję"}, status=status.HTTP_204_NO_CONTENT)

# 6. ANKIETY
@api_view(['POST'])
def poll_create(request, event_id):
    return Response({"id": "poll-1", "question": "Czym jedziemy?"}, status=status.HTTP_201_CREATED)

@api_view(['POST'])
def poll_option_create(request, event_id, poll_id):
    return Response({"id": "opt-1", "text": "Pociąg"}, status=status.HTTP_201_CREATED)

@api_view(['POST'])
def poll_vote(request, event_id, poll_id):
    return Response({"message": "Głos zapisany"}, status=status.HTTP_200_OK)

@api_view(['PUT'])
def poll_close(request, event_id, poll_id):
    return Response({"message": "Ankieta zamknięta"}, status=status.HTTP_200_OK)

# 7. CZAT
@api_view(['GET', 'POST'])
def chat_messages(request, event_id):
    if request.method == 'POST':
        return Response({"id": "msg-1", "text": "Hej"}, status=status.HTTP_201_CREATED)
    return Response([{"id": "msg-001", "text": "Cześć!"}], status=status.HTTP_200_OK)