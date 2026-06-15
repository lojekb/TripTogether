from django.urls import path
from . import views
from . import views_hotels
from . import views_transport

urlpatterns = [
    path('auth/register/', views.register_user, name='register_user'),
    path('auth/login/', views.login_user, name='login_user'),
    path('users/me/', views.user_profile, name='user_profile'),

    path('events/', views.event_list_create, name='event_list_create'),
    path('events/<str:event_id>/', views.event_detail_update, name='event_detail_update'),

    path('events/<str:event_id>/invitations/', views.generate_invitation, name='generate_invitation'),
    path('invitations/<str:token>/', views.invitation_preview, name='invitation_preview'),
    path('invitations/<str:token>/join/', views.join_event, name='join_event'),

    path('events/<str:event_id>/itinerary/', views.itinerary_list_create, name='itinerary_list_create'),
    path('events/<str:event_id>/itinerary/<str:item_id>/', views.itinerary_delete, name='itinerary_delete'),

    path('attractions/search/', views.search_attractions, name='search_attractions'),

    path('events/<str:event_id>/polls/', views.poll_create, name='poll_create'),
    path('events/<str:event_id>/polls/<str:poll_id>/options/', views.poll_option_create, name='poll_option_create'),
    path('events/<str:event_id>/polls/<str:poll_id>/vote/', views.poll_vote, name='poll_vote'),
    path('events/<str:event_id>/polls/<str:poll_id>/close/', views.poll_close, name='poll_close'),

    path('events/<str:event_id>/messages/', views.chat_messages, name='chat_messages'),

    path('hotels/search/', views_hotels.HotelSearchAPIView.as_view(), name='hotel_search'),

    path('transport/search/', views_transport.TransportSearchAPIView.as_view(), name='transport_search'),
]
