from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
import uuid



@api_view(['POST'])
def register_user(request):
    return Response({"message": "Użytkownik zarejestrowany", "userId": str(uuid.uuid4())},
                    status=status.HTTP_201_CREATED)


@api_view(['POST'])
def login_user(request):
    return Response({"token": "mocked.jwt.token"}, status=status.HTTP_200_OK)


@api_view(['GET', 'PUT'])
def user_profile(request):
    if request.method == 'GET':
        return Response({"id": "user-123", "name": "Jan Kowalski", "email": "jan@example.com"},
                        status=status.HTTP_200_OK)
    return Response({"message": "Profil zaktualizowany", "name": request.data.get('name')}, status=status.HTTP_200_OK)



@api_view(['GET', 'POST'])
def event_list_create(request):
    if request.method == 'POST':
        return Response({"id": str(uuid.uuid4()), "title": request.data.get('title'), "status": "DRAFT"},
                        status=status.HTTP_201_CREATED)
    return Response([{"id": "evt-001", "title": "Majówka w Rzymie", "status": "PLANNED"}], status=status.HTTP_200_OK)


@api_view(['GET', 'PUT'])
def event_detail_update(request, event_id):
    if request.method == 'GET':
        return Response({"id": event_id, "title": "Majówka w Rzymie", "city": "Rome"}, status=status.HTTP_200_OK)
    return Response({"message": "Zaktualizowano wydarzenie", "id": event_id}, status=status.HTTP_200_OK)



@api_view(['POST'])
def generate_invitation(request, event_id):
    return Response({"token": str(uuid.uuid4())[:8], "link": "https://app/join/token"}, status=status.HTTP_201_CREATED)


@api_view(['POST'])
def join_event(request, token):
    return Response({"message": f"Dołączono pomyślnie za pomocą tokenu {token}"}, status=status.HTTP_200_OK)



@api_view(['GET', 'POST'])
def itinerary_list_create(request, event_id):
    if request.method == 'POST':
        return Response({"id": "item-123", "type": "HOTEL", "message": "Dodano do planu"},
                        status=status.HTTP_201_CREATED)
    return Response([{"id": "item-001", "type": "FLIGHT", "details": "Lot Wizzair"}], status=status.HTTP_200_OK)


@api_view(['DELETE'])
def itinerary_delete(request, event_id, item_id):
    return Response({"message": "Usunięto pozycję z planu"}, status=status.HTTP_204_NO_CONTENT)



@api_view(['POST'])
def poll_create(request, event_id):
    return Response({"id": "poll-123", "question": "Czym jedziemy?"}, status=status.HTTP_201_CREATED)


@api_view(['POST'])
def poll_option_create(request, event_id, poll_id):
    return Response({"id": "opt-123", "text": "Pociąg"}, status=status.HTTP_201_CREATED)


@api_view(['POST'])
def poll_vote(request, event_id, poll_id):
    return Response({"message": "Głos zapisany", "pollOptionId": request.data.get('pollOptionId')},
                    status=status.HTTP_200_OK)


@api_view(['PUT'])
def poll_close(request, event_id, poll_id):
    return Response({"message": "Ankieta zamknięta", "winner": "opt-123"}, status=status.HTTP_200_OK)



@api_view(['GET', 'POST'])
def chat_messages(request, event_id):
    if request.method == 'POST':
        return Response({"id": "msg-1", "text": request.data.get('text'), "author": "User"},
                        status=status.HTTP_201_CREATED)
    return Response([{"id": "msg-001", "text": "Cześć wszystkim!", "author": "Jan"}], status=status.HTTP_200_OK)


from django.shortcuts import render

# Create your views here.
