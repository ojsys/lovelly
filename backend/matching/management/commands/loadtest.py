"""M2 acceptance load test: N simulated users over real websockets.

    docker compose -f infra/docker-compose.yml exec api python manage.py loadtest

Needs the matcher service running. Fails if any blocked pair is ever matched, or if the
median time to match is 10 s or more.
"""

import asyncio
import json
import random
import statistics
import time
from datetime import date

from django.core.management.base import BaseCommand, CommandError
from django.db.models import Q
from django.utils import timezone
from rest_framework_simplejwt.tokens import AccessToken

from accounts.models import Interest, Profile, User, UserInterest
from matching.models import MatchSession
from safety.models import Block

PHONE_PREFIX = "+23470010"
LOCAL_LANGUAGES = ["pidgin", "yoruba", "hausa", "igbo"]


class Command(BaseCommand):
    help = "Simulate users matching, chatting and pressing Next (M2 acceptance)."

    def add_arguments(self, parser):
        parser.add_argument("--users", type=int, default=500)
        parser.add_argument("--duration", type=int, default=180, help="seconds")
        parser.add_argument("--block-rate", type=float, default=0.10)
        parser.add_argument("--url", default="ws://localhost:8000/ws/")
        parser.add_argument(
            "--random-languages",
            action="store_true",
            help="Adversarial: random languages, so many pairs share nothing and must wait "
            "for the 30 s widening. Default: everyone speaks English, like Nigerian users.",
        )

    def handle(self, *args, **opts):
        started = timezone.now()
        users = self._seed(opts["users"], opts["block_rate"], opts["random_languages"])
        tokens = {str(u.id): str(AccessToken.for_user(u)) for u in users}
        stats = asyncio.run(self._run(tokens, opts["url"], opts["duration"]))
        self._report(stats, started)

    # --- setup -------------------------------------------------------------------------

    def _seed(self, n, block_rate, random_languages):
        User.objects.filter(phone__startswith=PHONE_PREFIX).delete()
        interests = list(Interest.objects.all())
        users = User.objects.bulk_create(
            [
                User(phone=f"{PHONE_PREFIX}{i:05d}", dob=date(1998, 1, 1), gender="other")
                for i in range(n)
            ]
        )
        # Older than a day, so the SF-7 new-account cap doesn't limit the run.
        User.objects.filter(id__in=[u.id for u in users]).update(
            created_at=timezone.now() - timezone.timedelta(days=3)
        )
        Profile.objects.bulk_create(
            [
                Profile(
                    user=u,
                    first_name=f"Load{i}",
                    languages=(
                        random.sample(["english", *LOCAL_LANGUAGES], random.randint(0, 2))
                        if random_languages
                        else ["english", *random.sample(LOCAL_LANGUAGES, random.randint(0, 1))]
                    ),
                    is_verified=True,
                    verified_at=timezone.now(),
                )
                for i, u in enumerate(users)
            ]
        )
        UserInterest.objects.bulk_create(
            [
                UserInterest(user=u, interest=i)
                for u in users
                for i in random.sample(interests, random.randint(0, 3))
            ]
        )
        blocks = [
            Block(blocker=a, blocked=b)
            for idx, a in enumerate(users)
            for b in users[idx + 1 :]
            if random.random() < block_rate
        ]
        Block.objects.bulk_create(blocks, batch_size=5000)
        self.stdout.write(f"seeded {n} users, {len(blocks)} blocked pairs")
        return users

    # --- simulation ----------------------------------------------------------------------

    async def _run(self, tokens, url, duration):
        import websockets

        waits, errors, matches = [], [], [0]
        deadline = time.monotonic() + duration

        async def client(token):
            mode = random.choice(["video", "voice", "text"])
            try:
                async with websockets.connect(
                    f"{url}?token={token}", origin="http://localhost", open_timeout=30
                ) as ws:
                    joined = time.monotonic()
                    await ws.send(json.dumps({"type": "queue.join", "mode": mode}))
                    while time.monotonic() < deadline:
                        try:
                            raw = await asyncio.wait_for(
                                ws.recv(), timeout=deadline - time.monotonic()
                            )
                        except TimeoutError:
                            break
                        event = json.loads(raw)
                        kind = event["type"]
                        if kind == "match.found":
                            waits.append(time.monotonic() - joined)
                            matches[0] += 1
                            sid = event["session_id"]
                            await ws.send(
                                json.dumps(
                                    {"type": "chat.message", "session_id": sid, "body": "hi"}
                                )
                            )
                            await asyncio.sleep(random.uniform(5.5, 12))
                            action = "session.next" if random.random() < 0.7 else "session.end"
                            await ws.send(json.dumps({"type": action, "session_id": sid}))
                        elif kind == "session.ended":
                            if event["reason"] in ("next",):
                                joined = time.monotonic()  # server re-queued us
                            elif event["reason"] in ("end", "peer_next", "peer_left", "blocked"):
                                await asyncio.sleep(random.uniform(0.2, 1.0))
                                joined = time.monotonic()
                                await ws.send(json.dumps({"type": "queue.join", "mode": mode}))
                        elif kind == "error" and event["code"] not in (
                            "in_session",
                            "session_ended",
                        ):
                            errors.append(event["code"])
                            if event["code"] == "cooldown":
                                await asyncio.sleep(event.get("retry_after", 5))
                                joined = time.monotonic()
                                await ws.send(json.dumps({"type": "queue.join", "mode": mode}))
            except Exception as e:  # noqa: BLE001
                if time.monotonic() < deadline:  # closing at the deadline isn't a failure
                    at = int(duration - (deadline - time.monotonic()))
                    errors.append(f"{type(e).__name__} at ~{at // 10 * 10}s: {e}"[:120])

        async def ramp():
            tasks = []
            for token in tokens.values():
                tasks.append(asyncio.create_task(client(token)))
                await asyncio.sleep(0.02)  # 50 connects/s
            await asyncio.gather(*tasks)

        await ramp()
        return {"waits": waits, "errors": errors, "matches": matches[0]}

    # --- report --------------------------------------------------------------------------

    def _report(self, stats, started):
        sessions = MatchSession.objects.filter(started_at__gte=started)
        pairs = set(sessions.values_list("user_a_id", "user_b_id"))
        blocked = set(
            Block.objects.filter(Q(blocker__phone__startswith=PHONE_PREFIX)).values_list(
                "blocker_id", "blocked_id"
            )
        )
        violations = [p for p in pairs if p in blocked or (p[1], p[0]) in blocked]
        waits = sorted(stats["waits"])
        median = statistics.median(waits) if waits else float("inf")
        p95 = waits[int(len(waits) * 0.95) - 1] if waits else float("inf")
        self.stdout.write(
            json.dumps(
                {
                    "sessions": sessions.count(),
                    "match_events": stats["matches"],
                    "median_wait_s": round(median, 2),
                    "p95_wait_s": round(p95, 2),
                    "blocked_pair_matches": len(violations),
                    "errors": {e: stats["errors"].count(e) for e in set(stats["errors"])},
                },
                indent=2,
            )
        )
        if violations:
            raise CommandError(f"{len(violations)} blocked pairs were matched")
        if median >= 10:
            raise CommandError(f"median wait {median:.1f}s is not under 10s")
        self.stdout.write(self.style.SUCCESS("load test passed"))
