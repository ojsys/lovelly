"""Creates a video and a voice session between two verified test users and prints their
LiveKit join tokens as JSON, for calltest/run.py (M3 acceptance)."""

import json
from datetime import date

from django.core.management.base import BaseCommand
from django.utils import timezone

from accounts.models import Profile, User
from matching import calls
from matching.models import MatchSession

PREFIX = "+23470020"


class Command(BaseCommand):
    def handle(self, *args, **opts):
        User.objects.filter(phone__startswith=PREFIX).delete()
        out = {}
        for mode in ("video", "voice"):
            a, b = (self._user(f"{PREFIX}{mode[:2]}{i}") for i in (1, 2))
            session = MatchSession.objects.create(
                mode=mode, user_a=a, user_b=b, room_name=f"calltest_{mode}_{timezone.now():%H%M%S}"
            )
            out[mode] = {
                "room": session.room_name,
                "a": calls.media_token(session, a.id),
                "b": calls.media_token(session, b.id),
            }
        self.stdout.write(json.dumps(out))

    def _user(self, phone):
        user = User.objects.create_user(phone=phone, dob=date(1998, 1, 1), gender="other")
        Profile.objects.create(
            user=user, first_name="Bot", is_verified=True, verified_at=timezone.now()
        )
        return user
