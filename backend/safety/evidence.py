"""Evidence for reports (SF-4): the last 30 s of sampled frames plus the chat transcript.

The moderation agent pushes every sampled frame into a short Redis ring buffer per
session and user; a report copies what's there into the private `evidence` bucket.
"""

import json
import time

from django.core.files.base import ContentFile
from django.core.files.storage import storages

from chat.models import Message
from core.redis import get_redis
from core.storage_urls import signed_url

WINDOW_SECONDS = 30
MAX_FRAMES = 40  # 1 frame/s for 30 s plus slack


def _key(session_id, user_id):
    return f"ev:{session_id}:{user_id}"


def push_frame(session_id, user_id, jpeg: bytes, at: float | None = None) -> None:
    at = at or time.time()
    r = get_redis()
    key = _key(session_id, user_id)
    pipe = r.pipeline()
    pipe.lpush(key, json.dumps({"at": at, "jpeg": jpeg.hex()}))
    pipe.ltrim(key, 0, MAX_FRAMES - 1)
    pipe.expire(key, WINDOW_SECONDS * 4)
    pipe.execute()


def recent_frames(session_id, user_id, now: float | None = None) -> list[tuple[float, bytes]]:
    now = now or time.time()
    frames = []
    for raw in get_redis().lrange(_key(session_id, user_id), 0, -1):
        item = json.loads(raw)
        if now - item["at"] <= WINDOW_SECONDS:
            frames.append((item["at"], bytes.fromhex(item["jpeg"])))
    return sorted(frames)


def storage():
    return storages["evidence"]


def capture(report, friendship=None) -> str:
    """Copies frames (both people) and the transcript into the evidence bucket.

    For a friend-chat report, the transcript is the friend chat's last 200 messages."""
    prefix = f"reports/{report.id}"
    session = report.session
    store = storage()
    frames = []
    if session is not None and friendship is None:
        for role, uid in (("reported", report.reported_id), ("reporter", report.reporter_id)):
            if uid is None:
                continue
            for at, jpeg in recent_frames(session.id, uid):
                key = store.save(f"{prefix}/frames/{role}/{at:.3f}.jpg", ContentFile(jpeg))
                frames.append({"role": role, "at": at, "key": key})
        transcript = [
            {
                "sender": "reported" if m.sender_id == report.reported_id else "reporter",
                "body": m.body,
                "sent_at": m.sent_at.isoformat(),
                "flagged": m.flagged,
            }
            for m in Message.objects.filter(session=session).order_by("sent_at")
        ]
    else:
        transcript = []
    if friendship is not None:
        recent = Message.objects.filter(friendship=friendship).order_by("-sent_at")[:200]
        transcript = [
            {
                "sender": "reported" if m.sender_id == report.reported_id else "reporter",
                "body": m.body,
                "sent_at": m.sent_at.isoformat(),
                "flagged": m.flagged,
            }
            for m in reversed(recent)
        ]
    manifest = {"frames": frames, "transcript": transcript}
    store.save(f"{prefix}/manifest.json", ContentFile(json.dumps(manifest).encode()))
    return prefix


def load(report) -> dict:
    """Evidence for the console, with short-lived signed URLs for frames."""
    if not report.evidence_uri:
        return {"frames": [], "transcript": []}
    store = storage()
    with store.open(f"{report.evidence_uri}/manifest.json") as f:
        manifest = json.load(f)
    for frame in manifest["frames"]:
        frame["url"] = signed_url(store, frame.pop("key"))
    return manifest


def delete(report) -> None:
    if report.legal_hold or not report.evidence_uri:
        return
    store = storage()
    with store.open(f"{report.evidence_uri}/manifest.json") as f:
        manifest = json.load(f)
    for frame in manifest["frames"]:
        store.delete(frame["key"])
    store.delete(f"{report.evidence_uri}/manifest.json")
