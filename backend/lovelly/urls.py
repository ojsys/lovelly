from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView

from billing.views import (
    AppleWebhookView,
    GoogleWebhookView,
    PlansView,
    PlusVerifyView,
    PurchaseVerifyView,
    SpendSettingsView,
)
from chat.views import (
    ChatMessagesView,
    FriendRequestAcceptView,
    FriendRequestDeclineView,
    FriendRequestsView,
    FriendsView,
)
from core.views import HealthView
from matching.views import (
    MediaTokenView,
    OnlineCountView,
    QuoteView,
    RematchView,
    SessionDetailView,
)
from safety.views import (
    BlockDetailView,
    BlocksView,
    MyStatusView,
    NoticeSeenView,
    ReportsView,
)
from wallet.views import (
    ChatGiftView,
    ClaimDailyView,
    GiftsView,
    InviteRedeemView,
    InviteView,
    LedgerView,
    PacksView,
    SessionGiftView,
    WalletView,
)

api_v1 = [
    path("health", HealthView.as_view(), name="health"),
    path("schema/", SpectacularAPIView.as_view(), name="schema"),
    path("", include("accounts.urls")),
    path("match/online-count", OnlineCountView.as_view(), name="online-count"),
    path("match/quote", QuoteView.as_view(), name="match-quote"),
    path("sessions/<uuid:session_id>/rematch", RematchView.as_view(), name="rematch"),
    path("plus/plans", PlansView.as_view(), name="plus-plans"),
    path("plus/verify", PlusVerifyView.as_view(), name="plus-verify"),
    path("me/spend-settings", SpendSettingsView.as_view(), name="spend-settings"),
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
    path("wallet", WalletView.as_view(), name="wallet"),
    path("wallet/ledger", LedgerView.as_view(), name="wallet-ledger"),
    path("wallet/claim-daily", ClaimDailyView.as_view(), name="wallet-claim-daily"),
    path("wallet/packs", PacksView.as_view(), name="wallet-packs"),
    path("me/invite", InviteView.as_view(), name="invite"),
    path("me/invite/redeem", InviteRedeemView.as_view(), name="invite-redeem"),
    path("gifts", GiftsView.as_view(), name="gifts"),
    path("sessions/<uuid:session_id>/gifts", SessionGiftView.as_view(), name="session-gifts"),
    path("chats/<uuid:chat_id>/gifts", ChatGiftView.as_view(), name="chat-gifts"),
    path("purchases/verify", PurchaseVerifyView.as_view(), name="purchase-verify"),
    path("webhooks/google", GoogleWebhookView.as_view(), name="webhook-google"),
    path("webhooks/apple", AppleWebhookView.as_view(), name="webhook-apple"),
    path("me/notices/<uuid:notice_id>/seen", NoticeSeenView.as_view(), name="notice-seen"),
]

urlpatterns = [
    path("django-admin/", admin.site.urls),
    path("api/v1/", include(api_v1)),
    path("admin-api/", include("safety.admin_api")),
]
