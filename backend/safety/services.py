"""Blocks (SF-5): two-way and permanent; the matcher never pairs a blocked pair (FR-7)."""

from django.db import IntegrityError

from accounts.models import User
from core.exceptions import ApiError
from matching import service as matching
from matching.models import MatchSession

from .models import Block


def block_from_session(user: User, session_id) -> Block:
    """Blocks the other person in a session. Clients never see other users' ids."""
    session = MatchSession.objects.filter(id=session_id).first()
    if session is None or not session.has(user.id):
        raise ApiError("not_found", "Session not found.", 404)
    peer_id = session.peer_of(user.id)
    try:
        block, _ = Block.objects.get_or_create(blocker=user, blocked_id=peer_id)
    except IntegrityError:
        block = Block.objects.get(blocker=user, blocked_id=peer_id)
    if session.ended_at is None:
        matching.end_session(session.id, user, "blocked")
    return block


def unblock(user: User, block_id) -> None:
    deleted, _ = Block.objects.filter(id=block_id, blocker=user).delete()
    if not deleted:
        raise ApiError("not_found", "Block not found.", 404)
