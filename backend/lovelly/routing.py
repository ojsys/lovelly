from django.urls import path

from core.consumers import RealtimeConsumer

websocket_urlpatterns = [
    path("ws/", RealtimeConsumer.as_asgi()),
]
