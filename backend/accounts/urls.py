from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from . import views

urlpatterns = [
    path("auth/otp/request", views.OtpRequestView.as_view(), name="otp-request"),
    path("auth/otp/verify", views.OtpVerifyView.as_view(), name="otp-verify"),
    path("auth/social", views.SocialSignInView.as_view(), name="social"),
    path("auth/refresh", TokenRefreshView.as_view(), name="refresh"),
    path("me/basics", views.BasicsView.as_view(), name="me-basics"),
    path("me/selfie", views.SelfieView.as_view(), name="me-selfie"),
    path("me/verification", views.VerificationView.as_view(), name="me-verification"),
]
