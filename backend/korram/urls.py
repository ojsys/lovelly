from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView

from chat.views import (
    ChatMessagesView,
    FriendRequestAcceptView,
    FriendRequestDeclineView,
    FriendRequestsView,
    FriendsView,
)
from core.views import HealthView
from matching.views import MediaTokenView, OnlineCountView, SessionDetailView
from safety.views import (
    BlockDetailView,
    BlocksView,
    MyStatusView,
    NoticeSeenView,
    ReportsView,
)

api_v1 = [
    path("health", HealthView.as_view(), name="health"),
    path("schema/", SpectacularAPIView.as_view(), name="schema"),
    path("", include("accounts.urls")),
    path("match/online-count", OnlineCountView.as_view(), name="online-count"),
    path("sessions/<uuid:session_id>", SessionDetailView.as_view(), name="session-detail"),
    path("sessions/<uuid:session_id>/media-token", MediaTokenView.as_view(), name="media-token"),
    path("blocks", BlocksView.as_view(), name="blocks"),
    path("blocks/<uuid:block_id>", BlockDetailView.as_view(), name="block-detail"),
    path("reports", ReportsView.as_view(), name="reports"),
    path("friends", FriendsView.as_view(), name="friends"),
    path("friends/requests", FriendRequestsView.as_view(), name="friend-requests"),
    path("friends/requests/<uuid:request_id>/accept", FriendRequestAcceptView.as_view()),
    path("friends/requests/<uuid:request_id>/decline", FriendRequestDeclineView.as_view()),
    path("chats/<uuid:chat_id>/messages", ChatMessagesView.as_view(), name="chat-messages"),
    path("me/status", MyStatusView.as_view(), name="me-status"),
    path("me/notices/<uuid:notice_id>/seen", NoticeSeenView.as_view(), name="notice-seen"),
]

urlpatterns = [
    path("django-admin/", admin.site.urls),
    path("api/v1/", include(api_v1)),
    path("admin-api/", include("safety.admin_api")),
]
