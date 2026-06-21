import uuid
from datetime import timedelta

from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.utils import timezone


class UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email is required')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(email, password, **extra_fields)


class User(AbstractUser):
    username = models.CharField(max_length=150, blank=True, unique=False)
    email = models.EmailField(unique=True)
    bio = models.TextField(blank=True, default='')
    date_of_birth = models.DateField(null=True, blank=True)
    phone_number = models.CharField(max_length=30, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    objects = UserManager()

    def __str__(self):
        return self.email


class Event(models.Model):
    class Status(models.TextChoices):
        DRAFT = 'DRAFT', 'Draft'
        ACTIVE = 'ACTIVE', 'Active'
        COMPLETED = 'COMPLETED', 'Completed'
        CANCELLED = 'CANCELLED', 'Cancelled'

    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, default='')
    destination_city = models.CharField(max_length=100)
    destination_country = models.CharField(max_length=100)
    start_date = models.DateField()
    end_date = models.DateField()
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    created_by = models.ForeignKey('api.User', on_delete=models.CASCADE, related_name='created_events')
    max_members = models.PositiveIntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title


class Membership(models.Model):
    class Role(models.TextChoices):
        OWNER = 'OWNER', 'Owner'
        ADMIN = 'ADMIN', 'Admin'
        MEMBER = 'MEMBER', 'Member'

    user = models.ForeignKey('api.User', on_delete=models.CASCADE, related_name='memberships')
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='memberships')
    role = models.CharField(max_length=10, choices=Role.choices, default=Role.MEMBER)
    joined_at = models.DateTimeField(auto_now_add=True)
    invited_by = models.ForeignKey(
        'api.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='sent_invitations',
    )

    class Meta:
        unique_together = [('user', 'event')]

    def __str__(self):
        return f'{self.user.email} – {self.event.title} ({self.role})'


class Invitation(models.Model):
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='invitations')
    inviter = models.ForeignKey('api.User', on_delete=models.CASCADE, related_name='sent_invites')
    token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    def save(self, *args, **kwargs):
        if not self.pk:
            self.expires_at = timezone.now() + timedelta(hours=24)
        super().save(*args, **kwargs)

    def is_valid(self):
        return timezone.now() < self.expires_at

    def __str__(self):
        return f'Invitation to {self.event.title} by {self.inviter.email}'

class ItineraryItem(models.Model):
    class ItemType(models.TextChoices):
        ATTRACTION = 'ATTRACTION', 'Attraction'
        HOTEL = 'HOTEL', 'Hotel'
        FLIGHT = 'FLIGHT', 'Flight'
        OTHER = 'OTHER', 'Other'

    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='itinerary')
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, default='')
    item_type = models.CharField(max_length=20, choices=ItemType.choices, default=ItemType.OTHER)
    external_id = models.CharField(max_length=100, blank=True, null=True)
    location_lat = models.FloatField(null=True, blank=True)
    location_lon = models.FloatField(null=True, blank=True)
    created_by = models.ForeignKey('api.User', on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} ({self.item_type})"


class ChatMessage(models.Model):
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(
        'api.User',
        on_delete=models.SET_NULL,
        null=True,
        related_name='chat_messages',
    )
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        sender = self.sender.username if self.sender else 'unknown'
        return f"{sender} @ {self.event_id}: {self.content[:30]}"


class Poll(models.Model):
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='polls')
    question = models.CharField(max_length=255)
    created_by = models.ForeignKey(
        'api.User',
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_polls',
    )
    is_closed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.question} ({self.event_id})"


class PollOption(models.Model):
    poll = models.ForeignKey(Poll, on_delete=models.CASCADE, related_name='options')
    text = models.CharField(max_length=255)
    created_by = models.ForeignKey(
        'api.User',
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_poll_options',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return self.text


class Vote(models.Model):
    poll = models.ForeignKey(Poll, on_delete=models.CASCADE, related_name='votes')
    option = models.ForeignKey(PollOption, on_delete=models.CASCADE, related_name='votes')
    user = models.ForeignKey('api.User', on_delete=models.CASCADE, related_name='votes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        # One vote per user per poll (changing vote updates the existing record).
        unique_together = [('poll', 'user')]

    def __str__(self):
        return f"{self.user_id} -> {self.option_id}"
