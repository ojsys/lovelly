"""Creates a video and a voice session between two verified test users and prints their
LiveKit join tokens as JSON, for calltest/run.py (M3 acceptance)."""

import json
from datetime import date

from django.core.management.base import BaseCommand
from django.utils import timezone

from accounts.models import Profile, User
from matching import calls
from matching.models import MatchSession
from safety.admin_api import MODERATORS

PREFIX = "+23470020"


class Command(BaseCommand):
    def handle(self, *args, **opts):
        # Users with moderation history can't be deleted (audit log); keep old ones.
        User.objects.filter(phone__startswith=PREFIX, moderation_actions__isnull=True).exclude(
            phone=f"{PREFIX}mod"
        ).delete()
        stamp = timezone.now().strftime("%H%M%S")
        # End earlier test sessions so the moderation agent isn't left watching them.
        MatchSession.objects.filter(ended_at=None, room_name__startswith="calltest_").update(
            ended_at=timezone.now(), end_reason="end"
        )
        out = {}
        for mode in ("video", "voice", "moderation"):
            a, b = (self._user(f"{PREFIX}{mode[:2]}{stamp}{i}") for i in (1, 2))
            session = MatchSession.objects.create(
                mode="voice" if mode == "voice" else "video",
                user_a=a,
                user_b=b,
                room_name=f"calltest_{mode}_{timezone.now():%H%M%S}",
            )
            out[mode] = {
                "session": str(session.id),
                "room": session.room_name,
                "a": calls.media_token(session, a.id),
                "b": calls.media_token(session, b.id),
            }
            if mode == "moderation":
                calls.watch(session)  # the moderation agent joins this one (SF-2)
        from django.contrib.auth.models import Group

        mod = User.objects.filter(phone=f"{PREFIX}mod").first() or User.objects.create_user(
            phone=f"{PREFIX}mod"
        )
        mod.is_staff = True
        mod.set_password("calltest-console")
        mod.save()
        mod.groups.add(Group.objects.get_or_create(name=MODERATORS)[0])
        out["console"] = {"phone": mod.phone, "password": "calltest-console"}
        self.stdout.write(json.dumps(out))

    def _user(self, phone):
        user = User.objects.create_user(phone=phone, dob=date(1998, 1, 1), gender="other")
        Profile.objects.create(
            user=user, first_name="Bot", is_verified=True, verified_at=timezone.now()
        )
        return user
