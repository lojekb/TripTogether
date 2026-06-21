from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from .models import Event, ItineraryItem, ChatMessage

class EventSerializer(serializers.ModelSerializer):
    class Meta:
        model = Event
        fields = '__all__' 
        read_only_fields = ('created_by',)

    def validate(self, data):
        start_date = data.get('start_date')
        end_date = data.get('end_date')

        if start_date and end_date and start_date > end_date:
            raise serializers.ValidationError({"end_date": "Data zakończenia nie może być wcześniejsza niż data rozpoczęcia wydarzenia."})
        
        return data


# User registration serializer
User = get_user_model()

class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ('id', 'email', 'username', 'password', 'password_confirm')
        read_only_fields = ('id',)

    def validate(self, attrs):
        password = attrs.get('password')
        password_confirm = attrs.pop('password_confirm', None)

        if password != password_confirm:
            raise serializers.ValidationError({"password_confirm": "Passwords do not match."})

        # Validate password using Django's validators
        validate_password(password)

        return attrs

    def create(self, validated_data):
        email = validated_data.get('email')
        username = validated_data.get('username', '')
        password = validated_data.get('password')
        user = User.objects.create_user(email=email, username=username, password=password)
        return user

class ItineraryItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = ItineraryItem
        fields = '__all__'
        read_only_fields = ('created_by', 'event', 'created_at')


class ChatMessageSerializer(serializers.ModelSerializer):
    sender_id = serializers.IntegerField(source='sender.id', read_only=True)
    sender_username = serializers.CharField(source='sender.username', read_only=True)

    class Meta:
        model = ChatMessage
        fields = ('id', 'content', 'created_at', 'sender_id', 'sender_username')
        read_only_fields = ('id', 'created_at', 'sender_id', 'sender_username')

    def validate_content(self, value):
        if not value or not value.strip():
            raise serializers.ValidationError("Wiadomość nie może być pusta.")
        return value.strip()
