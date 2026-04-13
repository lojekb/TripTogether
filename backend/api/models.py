from django.db import models

# Create your models here.
class Event(models.Model):
    title = models.CharField(max_length=255)
    city = models.CharField(max_length=100)
    start_date = models.DateField()
    end_date = models.DateField()
    status = models.CharField(max_length=20, default="DRAFT")