"""Decisions on sampled video frames (SF-2, SF-3). Called by the moderation agent."""

import logging
from dataclasses import dataclass

from django.conf import settings
from django.db import transaction

from accounts.models import User, Verification
from core.providers import get_provider
from core.realtime import batched, send_to_user
from matching import service as matching
from matching.models import MatchSession

from . import evidence
from .models import ModerationAction, Report
from .services import automatic_report

logger = logging.getLogger(__name__)

FAST_SECONDS = 30  # sample every 1 s for the first 30 s of a stream, then every 2 s


def sample_interval(stream_age_seconds: float) -> float:
    """M4 decision 1: dense sampling while most abuse happens, then the PRD's 2 s."""
    return 1.0 if stream_age_seconds < FAST_SECONDS else 2.0


@dataclass(frozen=True)
class Outcome:
    action: str  # ok | blocked | suspended | ended
    report_id: str | None = None


def handle_frame(session_id, user_id, track_sid: str, jpeg: bytes, at: float) -> Outcome:
    """Store the frame as evidence, scan it, and act on a hit."""
    session = MatchSession.objects.filter(id=session_id).first()
    if session is None or session.ended_at is not None:
        return Outcome("ended")
    evidence.push_frame(session.id, user_id, jpeg, at)
    verdict = get_provider("moderation").scan_frame(jpeg)

    if verdict.nudity >= settings.MODERATION_NUDITY_THRESHOLD:
        with batched():
            # Stop the stream for the viewer at once, then blur both apps and end the call.
            try:
                get_provider("media").mute_track(session.room_name, str(user_id), track_sid)
            except Exception:
                logger.exception("could not mute %s in %s", track_sid, session.room_name)
            for uid in (session.user_a_id, session.user_b_id):
                send_to_user(
                    uid, "moderation.blur", {"session_id": str(session.id), "reason": "nudity"}
                )
            report = automatic_report(
                session, user_id, Report.Reason.NUDITY, f"nudity {verdict.nudity:.2f}"
            )
            offender = User.objects.get(id=user_id)
            matching.end_session(session.id, offender, "moderation")
        return Outcome("blocked", str(report.id))

    if verdict.estimated_age is not None and verdict.estimated_age < settings.MIN_AGE:
        # SF-3: looks under 18 → suspended until a human reviews it.
        with transaction.atomic(), batched():
            offender = User.objects.select_for_update().get(id=user_id)
            offender.status = User.Status.SUSPENDED
            offender.suspended_until = None  # until review
            offender.save(update_fields=["status", "suspended_until"])
            Verification.objects.create(
                user=offender,
                kind=Verification.Kind.MANUAL,
                status=Verification.Status.PENDING,
                reason="age_estimate",
                estimated_age=verdict.estimated_age,
            )
            report = automatic_report(
                session, user_id, Report.Reason.MINOR, f"estimated age {verdict.estimated_age}"
            )
            ModerationAction.objects.create(
                target_user=offender, report=report, action=ModerationAction.Action.AUTO_SUSPEND
            )
            matching.end_session(session.id, offender, "moderation")
        return Outcome("suspended", str(report.id))

    return Outcome("ok")
