from dataclasses import asdict

from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from . import serializers as s
from .services import devices, onboarding, otp, phones

ERRORS = {400: s.ApiErrorSerializer, 403: s.ApiErrorSerializer, 429: s.ApiErrorSerializer}


def _state_body(user):
    state = onboarding.state(user)
    return {**asdict(state), "next_step": state.next_step}


def _session(user):
    return {**onboarding.tokens_for(user), "next_step": onboarding.state(user).next_step}


class OtpRequestView(APIView):
    """FR-1: text or call a 6-digit code. Signed-in Google/Apple users use this too (FR-2)."""

    permission_classes = [AllowAny]
    throttle_scope = "otp_request"

    @extend_schema(
        request=s.OtpRequestSerializer, responses={200: s.OtpRequestResponseSerializer, **ERRORS}
    )
    def post(self, request):
        data = s.OtpRequestSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        phone = phones.normalize(data.validated_data["phone"])
        devices.ensure_not_denied(request)
        resend_in = otp.request_code(phone, data.validated_data["channel"])
        return Response({"phone": phone, "masked": phones.masked(phone), "resend_in": resend_in})


class OtpVerifyView(APIView):
    permission_classes = [AllowAny]
    throttle_scope = "otp_verify"

    @extend_schema(request=s.OtpVerifySerializer, responses={200: s.SessionSerializer, **ERRORS})
    def post(self, request):
        data = s.OtpVerifySerializer(data=request.data)
        data.is_valid(raise_exception=True)
        phone = phones.normalize(data.validated_data["phone"])
        otp.ensure_not_denied(phone)
        devices.ensure_not_denied(request)
        otp.check_code(phone, data.validated_data["code"])
        current = request.user if request.user.is_authenticated else None
        user = onboarding.sign_in_with_phone(phone, current)
        devices.record(user, request)
        return Response(_session(user))


class SocialSignInView(APIView):
    permission_classes = [AllowAny]
    throttle_scope = "social"

    @extend_schema(request=s.SocialSignInSerializer, responses={200: s.SessionSerializer, **ERRORS})
    def post(self, request):
        data = s.SocialSignInSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        devices.ensure_not_denied(request)
        user = onboarding.sign_in_social(
            data.validated_data["provider"], data.validated_data["id_token"]
        )
        devices.record(user, request)
        return Response(_session(user))


class BasicsView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        request=s.BasicsSerializer, responses={200: s.VerificationStateSerializer, **ERRORS}
    )
    def put(self, request):
        data = s.BasicsSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        onboarding.set_basics(
            request.user,
            first_name=data.validated_data["first_name"],
            dob=data.validated_data["dob"],
            gender=data.validated_data["gender"],
        )
        return Response(_state_body(request.user))


class SelfieView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser]
    throttle_scope = "selfie"

    @extend_schema(
        request={"multipart/form-data": s.SelfieSerializer},
        responses={200: s.VerificationStateSerializer, 409: s.ApiErrorSerializer, **ERRORS},
    )
    def post(self, request):
        data = s.SelfieSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        onboarding.submit_selfie(
            request.user, data.validated_data["pose_front"], data.validated_data["pose_left"]
        )
        return Response(_state_body(request.user), status=status.HTTP_200_OK)


class VerificationView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses={200: s.VerificationStateSerializer})
    def get(self, request):
        return Response(_state_body(request.user))


class MyProfileView(APIView):
    """Read-only summary for Home and Matching; editing arrives with Profile (M5)."""

    permission_classes = [IsAuthenticated]

    @extend_schema(responses=s.MyProfileSerializer)
    def get(self, request):
        user = request.user
        profile = onboarding._profile(user)
        interests = [
            {"slug": ui.interest.slug, "label": ui.interest.label}
            for ui in user.interests.select_related("interest")
        ]
        return Response(
            {
                "first_name": profile.first_name,
                "age": onboarding.age_on(user.dob, timezone.now().date()) if user.dob else None,
                "city": profile.city,
                "interests": interests,
                "languages": profile.languages,
                "is_verified": profile.is_verified,
            }
        )
