"""Moderation agent (SF-2, SF-3): a hidden LiveKit participant in every video call.

It samples each video track (every 1 s for the first 30 s, then every 2 s), keeps the
frames as evidence and lets safety.moderation decide. Run several for more calls.
"""

import asyncio
import io
import json
import logging
import signal
import time
import uuid

from asgiref.sync import sync_to_async
from django.conf import settings
from django.core.management.base import BaseCommand
from django.db import close_old_connections
from django.db.models import Q

from core.providers import get_provider
from matching.calls import MODERATION_CHANNEL
from matching.models import MatchSession
from safety.moderation import handle_frame, sample_interval

logger = logging.getLogger(__name__)
JPEG_WIDTH = 320
EMPTY_SECONDS = 60  # leave rooms nobody is in (e.g. sessions never ended cleanly)
# A burst of new video calls queues here instead of stampeding the LiveKit SDK, which wedges
# when hundreds of rooms connect at once (found under the M7 load test).
MAX_CONCURRENT_JOINS = 4
JOIN_TIMEOUT_SECONDS = 10
# This many failed joins in a row means the SDK is stuck: exit, and Docker restarts us.
FAILED_JOINS_TO_RESTART = 5


def encode(frame) -> bytes:
    from livekit import rtc
    from PIL import Image

    rgba = frame.convert(rtc.VideoBufferType.RGBA)
    img = Image.frombuffer("RGBA", (rgba.width, rgba.height), bytes(rgba.data), "raw", "RGBA", 0, 1)
    img = img.convert("RGB")
    img.thumbnail((JPEG_WIDTH, JPEG_WIDTH * 2))
    out = io.BytesIO()
    img.save(out, "JPEG", quality=70)
    return out.getvalue()


def _db(fn):
    """Run ORM code in a worker thread with fresh connections."""

    def run(*args, **kwargs):
        close_old_connections()
        return fn(*args, **kwargs)

    return sync_to_async(run, thread_sensitive=False)


class Watch:
    def __init__(self, session_id: str, room_name: str):
        self.session_id, self.room_name = session_id, room_name
        self.tasks: set[asyncio.Task] = set()
        self.done = False
        from livekit import rtc

        self.room = rtc.Room()
        self.room.on("track_subscribed", self._on_track)
        self.empty_since: float | None = None

    def _on_track(self, track, publication, participant):
        from livekit import rtc

        if track.kind == rtc.TrackKind.KIND_VIDEO:
            task = asyncio.create_task(self._sample(track, publication.sid, participant.identity))
            self.tasks.add(task)
            task.add_done_callback(self.tasks.discard)

    async def _sample(self, track, track_sid: str, identity: str):
        from livekit import rtc

        # capacity=1: only the newest frame is kept, so a busy agent never falls behind.
        stream = rtc.VideoStream(track, capacity=1)
        started = time.monotonic()
        next_at = 0.0
        async for event in stream:
            if self.done:
                break
            now = time.monotonic()
            if now < next_at:
                continue
            next_at = now + sample_interval(now - started)
            jpeg = await asyncio.to_thread(encode, event.frame)
            outcome = await _db(handle_frame)(
                self.session_id, identity, track_sid, jpeg, time.time()
            )
            if outcome.action != "ok":
                logger.info(
                    "session %s: %s (%s)", self.session_id, outcome.action, outcome.report_id
                )
                await self.stop()
                break

    async def start(self):
        token = get_provider("media").agent_token(
            self.room_name, f"moderator-{uuid.uuid4().hex[:8]}", ttl_seconds=4 * 3600
        )
        await self.room.connect(settings.LIVEKIT_AGENT_URL, token)

    def check_empty(self, now: float) -> bool:
        """True once nobody but the agent has been in the room for EMPTY_SECONDS."""
        if self.room.remote_participants:
            self.empty_since = None
            return False
        self.empty_since = self.empty_since or now
        return now - self.empty_since > EMPTY_SECONDS

    async def stop(self):
        if self.done:
            return
        self.done = True
        for task in list(self.tasks):
            if task is not asyncio.current_task():
                task.cancel()
        await self.room.disconnect()


class Agent:
    def __init__(self):
        self.watches: dict[str, Watch] = {}
        self.joins = asyncio.Semaphore(MAX_CONCURRENT_JOINS)
        self.failed_joins = 0
        self.unhealthy = asyncio.Event()

    async def start(self, session_id: str, room_name: str):
        if session_id in self.watches:
            return
        watch = Watch(session_id, room_name)
        self.watches[session_id] = watch
        async with self.joins:
            if watch.done or self.watches.get(session_id) is not watch:
                return  # the call ended while it waited its turn
            try:
                await asyncio.wait_for(watch.start(), JOIN_TIMEOUT_SECONDS)
                self.failed_joins = 0
                if watch.done:  # stopped while connecting
                    await watch.room.disconnect()
                    return
                logger.info("watching %s", session_id)
            except Exception:
                logger.exception("could not join %s", room_name)
                self.watches.pop(session_id, None)
                self.failed_joins += 1
                if self.failed_joins >= FAILED_JOINS_TO_RESTART:
                    logger.error("%d joins failed in a row: restarting", self.failed_joins)
                    self.unhealthy.set()

    async def stop(self, session_id: str):
        watch = self.watches.pop(session_id, None)
        if watch and watch.room.isconnected():
            await watch.stop()
        elif watch:
            watch.done = True  # still queued to join: never join it

    @_db
    def _active(self):
        return list(
            MatchSession.objects.filter(ended_at=None)
            .filter(Q(mode=MatchSession.Mode.VIDEO) | Q(upgraded_at__isnull=False))
            .values_list("id", "room_name")
        )

    async def run(self, stop: asyncio.Event):
        import redis.asyncio as aioredis

        for session_id, room in await self._active():
            asyncio.create_task(self.start(str(session_id), room))
        r = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
        pubsub = r.pubsub()
        await pubsub.subscribe(MODERATION_CHANNEL)
        logger.info("moderation agent started")
        while not stop.is_set() and not self.unhealthy.is_set():
            msg = await pubsub.get_message(ignore_subscribe_messages=True, timeout=1.0)
            now = time.monotonic()
            for session_id, watch in list(self.watches.items()):
                if watch.check_empty(now):
                    logger.info("leaving empty room %s", session_id)
                    await self.stop(session_id)
            if not msg:
                continue
            event = json.loads(msg["data"])
            if event["op"] == "start":
                asyncio.create_task(self.start(event["session_id"], event["room"]))
            elif event["op"] == "stop":
                asyncio.create_task(self.stop(event["session_id"]))
        for session_id in list(self.watches):
            await self.stop(session_id)
        await pubsub.aclose()
        if self.unhealthy.is_set():
            raise SystemExit(1)


class Command(BaseCommand):
    help = "Moderation agent: samples video in live calls (SF-2, SF-3)."

    def handle(self, *args, **options):
        async def main():
            stop = asyncio.Event()
            loop = asyncio.get_running_loop()
            for sig in (signal.SIGTERM, signal.SIGINT):
                loop.add_signal_handler(sig, stop.set)
            await Agent().run(stop)

        asyncio.run(main())
