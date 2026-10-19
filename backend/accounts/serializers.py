from django.conf import settings
from rest_framework import serializers

from .models import SocialAccount, User


class OtpRequestSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=32)
    channel = serializers.ChoiceField(choices=["sms", "voice"], default="sms")


class OtpRequestResponseSerializer(serializers.Serializer):
    phone = serializers.CharField(help_text="E.164 form of the number")
    masked = serializers.CharField(help_text="e.g. +234 803 ••• ••42")
    resend_in = serializers.IntegerField(help_text="Seconds until another code may be sent")


class OtpVerifySerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=32)
    code = serializers.RegexField(rf"^\d{{{settings.OTP_LENGTH}}}$")


class SocialSignInSerializer(serializers.Serializer):
    provider = serializers.ChoiceField(choices=SocialAccount.Provider.choices)
    id_token = serializers.CharField()


class NextStep:
    CHOICES = ["phone", "basics", "selfie", "review", "done"]


class SessionSerializer(serializers.Serializer):
    access = serializers.CharField()
    refresh = serializers.CharField()
    next_step = serializers.ChoiceField(choices=NextStep.CHOICES)


class BasicsSerializer(serializers.Serializer):
    first_name = serializers.CharField(max_length=40, trim_whitespace=True)
    # Also accepts midnight datetimes: Dart's DateTime.toIso8601String() always adds a time.
    dob = serializers.DateField(
        input_formats=["iso-8601", "%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S"]
    )
    gender = serializers.ChoiceField(choices=User.Gender.choices)
    adult_confirmed = serializers.BooleanField()

    def validate_adult_confirmed(self, value):
        if not value:
            raise serializers.ValidationError("Confirm you're 18 or older.")
        return value


class SelfieSerializer(serializers.Serializer):
    pose_front = serializers.FileField()
    pose_left = serializers.FileField()


class VerificationStateSerializer(serializers.Serializer):
    phone_verified = serializers.BooleanField()
    basics_done = serializers.BooleanField()
    selfie = serializers.ChoiceField(
        choices=["none", "failed", "manual_review", "rejected", "passed"]
    )
    attempts_left = serializers.IntegerField()
    is_verified = serializers.BooleanField()
    next_step = serializers.ChoiceField(choices=NextStep.CHOICES)


class ApiErrorSerializer(serializers.Serializer):
    code = serializers.CharField()
    detail = serializers.CharField()
    retry_after = serializers.IntegerField(required=False)
