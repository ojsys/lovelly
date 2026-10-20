from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView

from core.views import HealthView
from matching.views import OnlineCountView, SessionDetailView
from safety.views import BlockDetailView, BlocksView

api_v1 = [
    path("health", HealthView.as_view(), name="health"),
    path("schema/", SpectacularAPIView.as_view(), name="schema"),
    path("", include("accounts.urls")),
    path("match/online-count", OnlineCountView.as_view(), name="online-count"),
    path("sessions/<uuid:session_id>", SessionDetailView.as_view(), name="session-detail"),
    path("blocks", BlocksView.as_view(), name="blocks"),
    path("blocks/<uuid:block_id>", BlockDetailView.as_view(), name="block-detail"),
]

urlpatterns = [
    path("django-admin/", admin.site.urls),
    path("api/v1/", include(api_v1)),
]
