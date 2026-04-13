from rest_framework import serializers
from .models import Event

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