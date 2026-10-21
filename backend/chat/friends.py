"""Friends (FR-14..FR-16): requests from a conversation, accept/decline, the friends list."""

from datetime import timedelta

from django.core.files.storage import default_storage
from django.db import transaction
from django.db.models import OuterRef, Q, Subquery
from django.utils import timezone
from rest_framework import status

from accounts.models import User
from accounts.services.onboarding import age_on
from accounts.services.push import notify
from core.exceptions import ApiError
from core.providers.push import Push
from core.realtime import send_to_user
from core.storage_urls import signed_url
from matching import service as matching
from matching.models import MatchSession
from safety.models import Block

from .models import Friendship, Message

REQUEST_WINDOW = timedelta(hours=1)
F = Friendship.Status


def blocked(a, b) -> bool:
    return Block.objects.filter(
        Q(blocker_id=a, blocked_id=b) | Q(blocker_id=b, blocked_id=a)
    ).exists()


def between(a, b) -> Friendship | None:
    return Friendship.objects.filter(
        Q(requester_id=a, addressee_id=b) | Q(requester_id=b, addressee_id=a)
    ).first()


def photo_url(user: User) -> str | None:
    profile = getattr(user, "profile", None)
    return (
        signed_url(default_storage, profile.photos[0], 3600) if profile and profile.photos else None
    )


def summary(user: User) -> dict:
    profile = user.profile
    return {
        "first_name": profile.first_name,
        "age": age_on(user.dob, timezone.now().date()) if user.dob else None,
        "city": profile.city,
        "verified": profile.is_verified,
        "photo_url": photo_url(user),
    }


def accepted_friendship(user, chat_id) -> Friendship:
    """The friendship `user` may chat or call in (FR-16), or 404."""
    f = Friendship.objects.filter(id=chat_id, status=F.ACCEPTED).first()
    if f is None or not f.has(user.id) or blocked(f.requester_id, f.addressee_id):
        raise ApiError("not_found", "Chat not found.", 404)
    return f


@transaction.atomic
def request(user: User, session_id) -> Friendship:
    """Add friend from a conversation: during it or within an hour after (FR-14)."""
    session = MatchSession.objects.filter(id=session_id).first()
    if session is None or not session.has(user.id):
        raise ApiError("not_found", "Session not found.", 404)
    if session.ended_at and session.ended_at < timezone.now() - REQUEST_WINDOW:
        raise ApiError("too_late", "Friend requests can be sent up to an hour after you meet.", 409)
    peer_id = session.peer_of(user.id)
    if blocked(user.id, peer_id):
        raise ApiError("not_found", "Session not found.", 404)

    existing = between(user.id, peer_id)
    if existing and existing.status == F.ACCEPTED:
        raise ApiError("already_friends", "You’re already friends.", status.HTTP_409_CONFLICT)
    if existing and existing.status == F.PENDING:
        if str(existing.requester_id) == str(user.id):
            return existing  # asked already
        return accept(user, existing.id)  # they asked too: both want it
    if existing:  # declined earlier: a fresh request from whoever asks now
        existing.requester, existing.addressee_id = user, peer_id
        existing.status, existing.met_in = F.PENDING, session
        existing.save(update_fields=["requester", "addressee", "status", "met_in"])
        friendship = existing
    else:
        friendship = Friendship.objects.create(requester=user, addressee_id=peer_id, met_in=session)

    transaction.on_commit(lambda: _announce_request(friendship, user, session))
    return friendship


def _announce_request(friendship: Friendship, user: User, session: MatchSession) -> None:
    send_to_user(
        friendship.addressee_id,
        "friend.request",
        {"request": request_row(friendship, viewer=friendship.addressee_id)},
    )
    notify(
        friendship.addressee_id,
        Push(
            "Lovelly", f"{user.profile.first_name} wants to be friends", {"type": "friend_request"}
        ),
    )


@transaction.atomic
def accept(user: User, request_id) -> Friendship:
    f = Friendship.objects.select_for_update().filter(id=request_id).first()
    if f is None or str(f.addressee_id) != str(user.id) or f.status != F.PENDING:
        raise ApiError("not_found", "Request not found.", 404)
    f.status, f.accepted_at = F.ACCEPTED, timezone.now()
    f.save(update_fields=["status", "accepted_at"])
    # FR-15: the stranger chat where they met becomes their saved history.
    if f.met_in_id:
        Message.objects.filter(session_id=f.met_in_id, friendship=None).update(friendship=f)

    def announce():
        for viewer in (f.requester_id, f.addressee_id):
            send_to_user(viewer, "friend.accepted", {"friend": friend_row(f, viewer)})
        notify(
            f.requester_id,
            Push(
                "Lovelly",
                f"{f.addressee.profile.first_name} accepted your friend request",
                {"type": "chat", "chat_id": str(f.id)},
            ),
        )

    transaction.on_commit(announce)
    return f


def decline(user: User, request_id) -> None:
    """Silent: the requester isn't told."""
    updated = Friendship.objects.filter(id=request_id, addressee=user, status=F.PENDING).update(
        status=F.DECLINED
    )
    if not updated:
        raise ApiError("not_found", "Request not found.", 404)


def end_for_block(a, b) -> None:
    """SF-5: blocked people can't see or message each other."""
    Friendship.objects.filter(
        Q(requester_id=a, addressee_id=b) | Q(requester_id=b, addressee_id=a)
    ).update(status=F.DECLINED)


# --- Lists -----------------------------------------------------------------------------


def friend_row(f: Friendship, viewer) -> dict:
    other = User.objects.select_related("profile").get(id=f.other(viewer))
    last = Message.objects.filter(friendship=f).order_by("-sent_at").first()
    unread = Message.objects.filter(friendship=f, seen_at=None).exclude(sender_id=viewer).count()
    return {
        "chat_id": str(f.id),
        "friend": summary(other),
        "online": matching.is_online(other.id),
        "last_message": last
        and {
            "body": last.body,
            "kind": last.kind,
            "mine": str(last.sender_id) == str(viewer),
            "sent_at": last.sent_at,
        },
        "unread": unread,
    }


def request_row(f: Friendship, viewer) -> dict:
    other = User.objects.select_related("profile").get(id=f.other(viewer))
    return {
        "id": str(f.id),
        "sender": summary(other),
        "met_on": f.met_in.mode if f.met_in else None,
        "created_at": f.created_at,
    }


def friends(user: User) -> dict:
    blocked_ids = set(
        Block.objects.filter(Q(blocker=user) | Q(blocked=user)).values_list(
            "blocker_id", "blocked_id"
        )
    )
    hidden = {str(x) for pair in blocked_ids for x in pair} - {str(user.id)}
    last_sent = Subquery(
        Message.objects.filter(friendship=OuterRef("pk")).order_by("-sent_at").values("sent_at")[:1]
    )
    accepted = (
        Friendship.objects.filter(Q(requester=user) | Q(addressee=user), status=F.ACCEPTED)
        .annotate(last_sent=last_sent)
        .order_by("-last_sent", "-accepted_at")
    )
    rows = [friend_row(f, user.id) for f in accepted if str(f.other(user.id)) not in hidden]
    pending = Friendship.objects.filter(addressee=user, status=F.PENDING).order_by("-created_at")
    requests = [request_row(f, user.id) for f in pending if str(f.requester_id) not in hidden]
    return {"friends": rows, "requests": requests}


def history(user: User, chat_id, before=None, limit: int = 30) -> dict:
    """Saved chat with a friend, newest first, paged by `before` (ISO time)."""
    f = accepted_friendship(user, chat_id)
    qs = Message.objects.filter(friendship=f).order_by("-sent_at")
    if before:
        qs = qs.filter(sent_at__lt=before)
    page = list(qs[: limit + 1])
    return {
        "friend": summary(User.objects.select_related("profile").get(id=f.other(user.id))),
        "messages": page[:limit],
        "more": len(page) > limit,
    }
