"""Moderator console API at /admin-api/ (SF-6). Staff in the "Moderators" group only.

Not part of the app's OpenAPI schema (`schema = None`), so it never reaches the Dart client.
"""

from django.contrib.auth import authenticate
from django.core.files.storage import default_storage
from django.db.models import Count, Q
from django.shortcuts import get_object_or_404
from django.urls import path
from django.utils import timezone
from rest_framework import serializers, status
from rest_framework.permissions import AllowAny, BasePermission
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User, Verification
from accounts.services import onboarding
from accounts.services.onboarding import age_on
from core.exceptions import ApiError
from core.ratelimit import limit
from core.storage_urls import signed_url

from . import evidence, services
from .models import ModerationAction, Report

MODERATORS = "Moderators"


def is_moderator(user) -> bool:
    return bool(
        user
        and user.is_authenticated
        and user.is_staff
        and (user.is_superuser or user.groups.filter(name=MODERATORS).exists())
    )


class IsModerator(BasePermission):
    message = "Moderators only."

    def has_permission(self, request, view):
        return is_moderator(request.user)


class ConsoleView(APIView):
    schema = None
    permission_classes = [IsModerator]


def user_summary(user: User) -> dict:
    profile = getattr(user, "profile", None)
    return {
        "id": str(user.id),
        "first_name": profile.first_name if profile else "",
        "age": age_on(user.dob, timezone.now().date()) if user.dob else None,  # never the DOB
        "city": profile.city if profile else "",
        "verified": bool(profile and profile.is_verified),
        "status": user.status,
        "suspended_until": user.suspended_until,
        "risk_score": user.risk_score,
        "joined": user.created_at,
        "reports_received": Report.objects.filter(reported=user).count(),
        "actions": [
            {"action": a.action, "at": a.created_at, "note": a.note}
            for a in ModerationAction.objects.filter(target_user=user)[:10]
        ],
    }


def report_row(r: Report) -> dict:
    return {
        "id": str(r.id),
        "reason": r.reason,
        "severity": r.severity,
        "status": r.status,
        "automatic": r.automatic,
        "legal_hold": r.legal_hold,
        "created_at": r.created_at,
        "reported": {"id": str(r.reported_id), "first_name": r.reported.profile.first_name},
        "mode": r.session.mode if r.session else None,
        "session_id": str(r.session_id) if r.session_id else None,
    }


class LoginView(APIView):
    schema = None
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        phone, password = request.data.get("phone", ""), request.data.get("password", "")
        limit(f"console-login:{phone}", 10, 900, "Too many attempts. Wait 15 minutes.")
        user = authenticate(request, phone=phone, password=password)
        if not is_moderator(user):
            raise ApiError("not_moderator", "Wrong phone or password, or not a moderator.", 401)
        return Response(onboarding.tokens_for(user))


class ReportsView(ConsoleView):
    """Queue sorted by severity, then oldest first (SF-6)."""

    def get(self, request):
        wanted = request.query_params.get("status", "open")
        qs = Report.objects.select_related("reported__profile", "session")
        if wanted == "open":
            qs = qs.filter(status__in=[Report.Status.OPEN, Report.Status.ESCALATED])
        elif wanted != "all":
            qs = qs.filter(status=wanted)
        if (auto := request.query_params.get("automatic")) in ("true", "false"):
            qs = qs.filter(automatic=auto == "true")
        counts = (
            Report.objects.filter(status__in=[Report.Status.OPEN, Report.Status.ESCALATED])
            .values("reason")
            .annotate(n=Count("id"))
        )
        return Response(
            {
                "results": [report_row(r) for r in qs.order_by("-severity", "created_at")[:200]],
                "open_by_reason": {c["reason"]: c["n"] for c in counts},
            }
        )


class ReportDetailView(ConsoleView):
    def get(self, request, report_id):
        r = get_object_or_404(
            Report.objects.select_related("reported__profile", "reporter__profile", "session"),
            id=report_id,
        )
        s = r.session
        return Response(
            {
                **report_row(r),
                "referral": r.referral,
                "closed_at": r.closed_at,
                "session": s
                and {
                    "mode": s.mode,
                    "started_at": s.started_at,
                    "ended_at": s.ended_at,
                    "end_reason": s.end_reason,
                },
                "reported": user_summary(r.reported),
                "reporter": user_summary(r.reporter) if r.reporter else None,
                "evidence": evidence.load(r),
                "history": [
                    {
                        "action": a.action,
                        "at": a.created_at,
                        "note": a.note,
                        "moderator": a.moderator.phone if a.moderator else "automatic",
                    }
                    for a in ModerationAction.objects.filter(report=r).select_related("moderator")
                ],
            }
        )


class ActionRequest(serializers.Serializer):
    action = serializers.ChoiceField(
        choices=[
            "warn",
            "suspend_24h",
            "suspend_7d",
            "ban",
            "dismiss",
            "escalate",
            "legal_hold",
            "referral",
        ]
    )
    note = serializers.CharField(required=False, allow_blank=True, default="")
    referral = serializers.DictField(required=False)


class ReportActionView(ConsoleView):
    def post(self, request, report_id):
        data = ActionRequest(data=request.data)
        data.is_valid(raise_exception=True)
        report = get_object_or_404(Report.objects.select_related("reported"), id=report_id)
        action = services.act(request.user, report, **data.validated_data)
        return Response(
            {"id": str(action.id), "action": action.action}, status=status.HTTP_201_CREATED
        )


class VerificationsView(ConsoleView):
    """Manual selfie reviews (FR-4, SF-3), moved here from Django admin."""

    def get(self, request):
        pending = Verification.objects.filter(
            kind=Verification.Kind.MANUAL, status=Verification.Status.PENDING
        ).select_related("user__profile")
        rows = []
        for v in pending.order_by("created_at"):
            latest = (
                Verification.objects.filter(user=v.user, kind=Verification.Kind.SELFIE)
                .exclude(images=[])
                .first()
            )
            rows.append(
                {
                    "id": str(v.id),
                    "reason": v.reason,
                    "estimated_age": v.estimated_age,
                    "created_at": v.created_at,
                    "user": user_summary(v.user),
                    "images": [
                        signed_url(default_storage, key)
                        for key in (latest.images if latest else [])
                    ],
                }
            )
        return Response({"results": rows})


class VerificationDecisionView(ConsoleView):
    def post(self, request, verification_id):
        approve = bool(request.data.get("approve"))
        manual = get_object_or_404(Verification, id=verification_id)
        onboarding.review(manual, request.user, approve)
        ModerationAction.objects.create(
            target_user=manual.user,
            moderator=request.user,
            action=ModerationAction.Action.APPROVE_SELFIE
            if approve
            else ModerationAction.Action.REJECT_SELFIE,
            note=request.data.get("note", ""),
        )
        return Response({"status": "approved" if approve else "rejected"})


class AuditView(ConsoleView):
    def get(self, request):
        q = request.query_params.get("user")
        actions = ModerationAction.objects.select_related("moderator", "target_user__profile")
        if q:
            actions = actions.filter(Q(target_user_id=q))
        return Response(
            {
                "results": [
                    {
                        "id": str(a.id),
                        "action": a.action,
                        "at": a.created_at,
                        "note": a.note,
                        "duration": a.duration.total_seconds() if a.duration else None,
                        "moderator": a.moderator.phone if a.moderator else "automatic",
                        "target": a.target_user.profile.first_name
                        if hasattr(a.target_user, "profile")
                        else str(a.target_user_id),
                        "report_id": str(a.report_id) if a.report_id else None,
                    }
                    for a in actions[:200]
                ]
            }
        )


urlpatterns = [
    path("auth/login", LoginView.as_view()),
    path("reports", ReportsView.as_view()),
    path("reports/<uuid:report_id>", ReportDetailView.as_view()),
    path("reports/<uuid:report_id>/actions", ReportActionView.as_view()),
    path("verifications", VerificationsView.as_view()),
    path("verifications/<uuid:verification_id>", VerificationDecisionView.as_view()),
    path("audit", AuditView.as_view()),
]
