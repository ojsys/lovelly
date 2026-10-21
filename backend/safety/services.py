"""Reports, blocks and moderation (SF-4..SF-9)."""

from datetime import timedelta

from django.db import IntegrityError, transaction
from django.utils import timezone

from accounts.models import DeniedDevice, DeniedPhone, User
from accounts.services.phones import phone_hash
from core.exceptions import ApiError
from core.ratelimit import limit
from core.realtime import send_to_user
from matching import service as matching
from matching.models import MatchSession

from . import evidence
from .models import Block, ModerationAction, Notice, Report

A = ModerationAction.Action
REPORTS_PER_HOUR = 10


# --- Blocks (SF-5) -----------------------------------------------------------------------


def _own_session(user: User, session_id) -> MatchSession:
    session = MatchSession.objects.filter(id=session_id).first()
    if session is None or not session.has(user.id):
        raise ApiError("not_found", "Session not found.", 404)
    return session


def _block(user: User, peer_id) -> Block:
    from chat.friends import end_for_block

    try:
        block, _ = Block.objects.get_or_create(blocker=user, blocked_id=peer_id)
    except IntegrityError:
        block = Block.objects.get(blocker=user, blocked_id=peer_id)
    end_for_block(user.id, peer_id)  # SF-5: no more friend chat either
    return block


def block_from_session(user: User, session_id) -> Block:
    """Blocks the other person in a session. Clients never see other users' ids."""
    session = _own_session(user, session_id)
    block = _block(user, session.peer_of(user.id))
    if session.ended_at is None:
        matching.end_session(session.id, user, "blocked")
    return block


def unblock(user: User, block_id) -> None:
    deleted, _ = Block.objects.filter(id=block_id, blocker=user).delete()
    if not deleted:
        raise ApiError("not_found", "Block not found.", 404)


# --- Reports (SF-4) ----------------------------------------------------------------------


def create_report(user: User, session_id, reason: str, block: bool, chat_id=None) -> Report:
    """User report from screen 08: evidence saved, session ended, optional block.

    From a friend chat (`chat_id`) the report points at the session where they met and the
    evidence is the friend chat (app-store rule: report in every chat)."""
    limit(f"report:{user.id}", REPORTS_PER_HOUR, 3600, "You've sent a lot of reports. Try later.")
    if chat_id:
        from chat.friends import accepted_friendship

        friendship = accepted_friendship(user, chat_id)
        peer_id = friendship.other(user.id)
        report = Report(
            reporter=user,
            reported_id=peer_id,
            session=friendship.met_in,
            reason=reason,
            severity=Report.SEVERITY[reason],
        )
        report.evidence_uri = evidence.capture(report, friendship=friendship)
        report.save()
        if block:
            _block(user, peer_id)
        return report
    session = _own_session(user, session_id)
    peer_id = session.peer_of(user.id)
    report = Report(
        reporter=user,
        reported_id=peer_id,
        session=session,
        reason=reason,
        severity=Report.SEVERITY[reason],
    )
    # Evidence first, then one save: the console never sees a report without evidence.
    report.evidence_uri = evidence.capture(report)
    report.save()
    if block:
        _block(user, peer_id)
    if session.ended_at is None:
        matching.end_session(session.id, user, "blocked" if block else "end")
    return report


def automatic_report(session: MatchSession, offender_id, reason: str, note: str) -> Report:
    """Raised by the moderation agent (SF-2, SF-3)."""
    report = Report(
        reporter=None,
        reported_id=offender_id,
        session=session,
        reason=reason,
        severity=Report.SEVERITY[reason],
        automatic=True,
    )
    report.evidence_uri = evidence.capture(report)
    report.save()
    ModerationAction.objects.create(
        target_user_id=offender_id, report=report, action=A.AUTO_BLOCK, note=note
    )
    return report


# --- Account status ------------------------------------------------------------------------


def effective_status(user: User) -> str:
    """Lifts timed suspensions that are over."""
    if (
        user.status == User.Status.SUSPENDED
        and user.suspended_until
        and user.suspended_until <= timezone.now()
    ):
        user.status, user.suspended_until = User.Status.ACTIVE, None
        user.save(update_fields=["status", "suspended_until"])
    return user.status


def _cut_off(user: User, reason: str) -> None:
    """Ends any live session and closes the user's sockets."""
    session = matching.active_session(user.id)
    if session:
        matching.end_session(session.id, user, "moderation")
    matching.leave(user.id)
    send_to_user(user.id, "account.closed", {"reason": reason})


# --- Moderator actions (SF-6) --------------------------------------------------------------


def _close(report: Report | None, status: str) -> None:
    if report and report.status in (Report.Status.OPEN, Report.Status.ESCALATED):
        report.status, report.closed_at = status, timezone.now()
        report.save(update_fields=["status", "closed_at"])


@transaction.atomic
def act(
    moderator: User, report: Report, action: str, note: str = "", referral=None
) -> ModerationAction:
    target = report.reported
    duration = None
    match action:
        case "warn":
            Notice.objects.create(
                user=target,
                kind="warning",
                title="A warning from the Lovelly team",
                body=note
                or "Your behaviour broke our Community Guidelines. "
                "Another report could get your account suspended.",
            )
            _close(report, Report.Status.ACTIONED)
            kind = A.WARN
        case "suspend_24h" | "suspend_7d":
            duration = timedelta(hours=24) if action == "suspend_24h" else timedelta(days=7)
            target.status = User.Status.SUSPENDED
            target.suspended_until = timezone.now() + duration
            target.save(update_fields=["status", "suspended_until"])
            transaction.on_commit(lambda: _cut_off(target, "suspended"))
            _close(report, Report.Status.ACTIONED)
            kind = A.SUSPEND
        case "ban":
            target.status, target.is_active = User.Status.BANNED, False
            target.save(update_fields=["status", "is_active"])
            if target.phone:
                DeniedPhone.objects.get_or_create(
                    phone_hash=phone_hash(target.phone), defaults={"reason": "ban"}
                )
            for d in target.devices.all():
                DeniedDevice.objects.get_or_create(
                    device_hash=d.device_hash, defaults={"reason": "ban"}
                )
            transaction.on_commit(lambda: _cut_off(target, "banned"))
            _close(report, Report.Status.ACTIONED)
            kind = A.BAN
        case "dismiss":
            _close(report, Report.Status.DISMISSED)
            kind = A.DISMISS
        case "escalate":
            report.status = Report.Status.ESCALATED
            report.save(update_fields=["status"])
            kind = A.ESCALATE
        case "legal_hold":
            # SF-9: evidence is kept and can't be deleted (DB trigger + purge skips it).
            report.legal_hold = True
            report.status = Report.Status.ESCALATED
            report.save(update_fields=["legal_hold", "status"])
            kind = A.LEGAL_HOLD
        case "referral":
            if not report.legal_hold:
                raise ApiError("not_on_hold", "Put the report on legal hold first.", 409)
            if not referral or not referral.get("agency") or not referral.get("reference"):
                raise ApiError("referral_incomplete", "Give the agency and reference.")
            report.referral = {**referral, "recorded_by": str(moderator.id)}
            report.save(update_fields=["referral"])
            kind = A.REFERRAL
        case _:
            raise ApiError("invalid_action", f"Unknown action: {action}")
    return ModerationAction.objects.create(
        target_user=target,
        moderator=moderator,
        report=report,
        action=kind,
        duration=duration,
        note=note,
    )


def purge_evidence(now=None) -> int:
    """SF-4: evidence is kept for 30 days after a report closes, unless held (SF-9)."""
    cutoff = (now or timezone.now()) - timedelta(days=30)
    purged = 0
    for report in Report.objects.filter(
        closed_at__lt=cutoff,
        legal_hold=False,
        status__in=[Report.Status.ACTIONED, Report.Status.DISMISSED],
    ).exclude(evidence_uri=""):
        evidence.delete(report)
        report.evidence_uri = ""
        report.save(update_fields=["evidence_uri"])
        purged += 1
    return purged
