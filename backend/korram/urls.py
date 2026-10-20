from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView

from core.views import HealthView
from matching.views import MediaTokenView, OnlineCountView, SessionDetailView
from safety.views import BlockDetailView, BlocksView

api_v1 = [
    path("health", HealthView.as_view(), name="health"),
    path("schema/", SpectacularAPIView.as_view(), name="schema"),
    path("", include("accounts.urls")),
    path("match/online-count", OnlineCountView.as_view(), name="online-count"),
    path("sessions/<uuid:session_id>", SessionDetailView.as_view(), name="session-detail"),
    path("sessions/<uuid:session_id>/media-token", MediaTokenView.as_view(), name="media-token"),
    path("blocks", BlocksView.as_view(), name="blocks"),
    path("blocks/<uuid:block_id>", BlockDetailView.as_view(), name="block-detail"),
]

urlpatterns = [
    path("django-admin/", admin.site.urls),
    path("api/v1/", include(api_v1)),
]
