"""Gifts (MN-5): the sender pays from the catalogue price; the receiver gets nothing back."""

from django.db import transaction

from accounts.models import User
from accounts.services.push import notify
from chat.friends import blocked
from chat.models import Message
from chat.services import conversation, serialize
from core.exceptions import ApiError
from core.providers.push import Push
from core.ratelimit import limit
from core.realtime import send_to_user

from .models import CoinLedger, Gift, GiftSend
from .services import balance, post_entry


def catalogue() -> list[Gift]:
    return list(Gift.objects.filter(active=True))


def gift_dict(gift: Gift) -> dict:
    return {"slug": gift.slug, "name": gift.name, "cost": gift.cost}


def send(user: User, gift_slug: str, client_key: str, session_id=None, chat_id=None) -> dict:
    """Sends a gift in a live session (04, 06) or a friend chat, once per `client_key`."""
    conv = conversation(user, session_id, chat_id)
    receiver_id = conv.peer_of(user.id)
    if blocked(user.id, receiver_id):
        raise ApiError("not_found", "Chat not found.", 404)
    gift = Gift.objects.filter(slug=gift_slug, active=True).first()
    if gift is None:
        raise ApiError("not_found", "That gift isn’t available.", 404)
    limit(f"gifts:{user.id}", 30, 60)

    with transaction.atomic():
        posted = post_entry(
            user.id,
            -gift.cost,  # the price is the catalogue's, never the app's (CLAUDE.md)
            CoinLedger.Reason.GIFT,
            key=f"gift:{user.id}:{client_key}",
            ref_type="gift",
            ref_id=gift.slug,
        )
        if not posted.created:  # a retry of a gift already sent
            sent = GiftSend.objects.get(ledger_entry=posted.entry)
            return {"id": sent.id, "gift": gift_dict(sent.gift), "balance": balance(user.id)}
        sent = GiftSend.objects.create(
            sender=user,
            receiver_id=receiver_id,
            session=conv.session,
            friendship=conv.friendship,
            gift=gift,
            cost=gift.cost,
            ledger_entry=posted.entry,
        )
        # Shown in the chat and kept in a friend's saved history; body is the gift slug.
        message = Message.objects.create(
            session=conv.session,
            friendship=conv.friendship,
            sender=user,
            body=gift.slug,
            kind=Message.Kind.GIFT,
        )

        def announce():
            event = {**conv.ref, "gift": gift_dict(gift), "sender_id": str(user.id)}
            for uid in conv.members:
                send_to_user(uid, "chat.message", {**conv.ref, "message": serialize(message)})
                send_to_user(uid, "gift.received", event)
            if conv.friendship:
                notify(
                    receiver_id,
                    Push(
                        "Korram",
                        f"{user.profile.first_name} sent you a gift",
                        {"type": "chat", "chat_id": str(conv.friendship.id)},
                    ),
                )

        transaction.on_commit(announce)
    return {"id": sent.id, "gift": gift_dict(gift), "balance": balance(user.id)}
