"""M3 acceptance at the SFU level: two headless participants through our LiveKit.

Runs inside the LiveKit container's network namespace (so `tc netem` on `lo` shapes the
client <-> SFU link). Tokens come from `manage.py calltest_setup`.

Checks (PRD M3 accept):
  1. a call connects on 4G and on simulated 3G, with audio and video flowing both ways
  2. mute and camera-off are seen by the other side
  3. a dropped connection (5 s blackout) rejoins within 10 s
  4. a voice-call token cannot publish camera (FR-14)
"""

import asyncio
import json
import math
import subprocess
import sys
import time

from livekit import rtc

URL = "ws://127.0.0.1:7880"
RATE, CHUNK = 48000, 480  # 10 ms audio frames
W, H, FPS = 320, 240, 15

PROFILES = {
    # delay is one-way per packet on lo, so RTT is about twice this.
    "4g": "delay 25ms 5ms rate 12mbit loss 0.2%",
    "3g": "delay 75ms 20ms rate 750kbit loss 1%",
    "blackout": "loss 100%",
}


def netem(profile: str | None) -> None:
    subprocess.run(["tc", "qdisc", "del", "dev", "lo", "root"], capture_output=True)
    if profile:
        subprocess.run(
            ["tc", "qdisc", "add", "dev", "lo", "root", "netem", *PROFILES[profile].split()],
            check=True,
        )
    shown = subprocess.run(["tc", "qdisc", "show", "dev", "lo"], capture_output=True, text=True)
    print(f"      [net {profile or 'clear'}] {shown.stdout.strip()}", flush=True)


class Peer:
    def __init__(self, name: str, token: str, video: bool = True):
        self.name, self.token, self.video = name, token, video
        self.frames = {"audio": 0, "video": 0}
        self.last_frame = {"audio": 0.0, "video": 0.0}
        self.events: list[tuple[float, str]] = []
        self.tasks: list[asyncio.Task] = []
        self.audio_track = None
        self.video_pub = None
        self.leaving = False
        self.rejoins = 0
        self.inject = None  # RGBA bytes to send instead of the normal frames
        self._new_room()

    def _new_room(self):
        self.room = rtc.Room()

        @self.room.on("track_subscribed")
        def _sub(track, publication, participant):
            kind = "audio" if track.kind == rtc.TrackKind.KIND_AUDIO else "video"
            stream = rtc.AudioStream(track) if kind == "audio" else rtc.VideoStream(track)
            self.tasks.append(asyncio.create_task(self._count(kind, stream)))

        for event in ("reconnecting", "reconnected"):
            self.room.on(event, lambda *_, e=event: self.events.append((time.monotonic(), e)))

        @self.room.on("disconnected")
        def _gone(*_):
            self.events.append((time.monotonic(), "disconnected"))
            if not self.leaving:
                # What the app does when LiveKit gives up: rejoin with a fresh token.
                self.tasks.append(asyncio.create_task(self._rejoin()))

        self.room.on("track_muted", lambda *_: self.events.append((time.monotonic(), "peer_muted")))
        self.room.on(
            "track_unmuted", lambda *_: self.events.append((time.monotonic(), "peer_unmuted"))
        )
        self.room.on(
            "disconnected", lambda *_: self.events.append((time.monotonic(), "room_closed"))
        )
        self.room.on(
            "track_unpublished",
            lambda *_: self.events.append((time.monotonic(), "peer_unpublished")),
        )

    async def _count(self, kind, stream):
        async for _ in stream:
            self.frames[kind] += 1
            self.last_frame[kind] = time.monotonic()

    async def _rejoin(self):
        for t in self.tasks:
            if t is not asyncio.current_task():
                t.cancel()
        self.tasks = [asyncio.current_task()]
        self._new_room()
        self.rejoins += 1
        for _attempt in range(20):
            try:
                await asyncio.wait_for(self.join(), 10)
                self.events.append((time.monotonic(), "rejoined"))
                return
            except Exception:  # noqa: BLE001
                await asyncio.sleep(0.5)

    @property
    def connected(self) -> bool:
        return self.room.connection_state == rtc.ConnectionState.CONN_CONNECTED

    async def join(self):
        await self.room.connect(URL, self.token, rtc.RoomOptions(auto_subscribe=True))
        source = rtc.AudioSource(RATE, 1)
        self.audio_track = rtc.LocalAudioTrack.create_audio_track("mic", source)
        await self.room.local_participant.publish_track(
            self.audio_track, rtc.TrackPublishOptions(source=rtc.TrackSource.SOURCE_MICROPHONE)
        )
        self.tasks.append(asyncio.create_task(self._tone(source)))
        if self.video:
            await self.publish_camera()

    async def publish_camera(self):
        vsource = rtc.VideoSource(W, H)
        track = rtc.LocalVideoTrack.create_video_track("cam", vsource)
        self.video_pub = await self.room.local_participant.publish_track(
            track, rtc.TrackPublishOptions(source=rtc.TrackSource.SOURCE_CAMERA)
        )
        self.tasks.append(asyncio.create_task(self._frames(vsource)))

    async def _tone(self, source):
        t = 0
        while True:
            frame = rtc.AudioFrame.create(RATE, 1, CHUNK)
            data = memoryview(frame.data).cast("h")
            for i in range(CHUNK):
                data[i] = int(8000 * math.sin(2 * math.pi * 440 * (t + i) / RATE))
            t += CHUNK
            await source.capture_frame(frame)

    async def _frames(self, source):
        n = 0
        while True:
            shade = (n * 8) % 256
            buf = self.inject or bytes([shade, 128, 255 - shade, 255]) * (W * H)
            source.capture_frame(rtc.VideoFrame(W, H, rtc.VideoBufferType.RGBA, buf))
            n += 1
            await asyncio.sleep(1 / FPS)

    def rate(self, kind, since_frames, seconds):
        return (self.frames[kind] - since_frames) / seconds

    async def leave(self):
        self.leaving = True
        for t in self.tasks:
            t.cancel()
        await self.room.disconnect()


results: list[tuple[str, bool, str]] = []


def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {detail}", flush=True)


async def flowing(a: Peer, b: Peer, seconds=4.0):
    before = {p.name: dict(p.frames) for p in (a, b)}
    await asyncio.sleep(seconds)
    return {
        p.name: {k: round((p.frames[k] - before[p.name][k]) / seconds, 1) for k in p.frames}
        for p in (a, b)
    }


async def call_on(profile, tokens):
    netem(profile)
    a, b = Peer("A", tokens["a"]), Peer("B", tokens["b"])
    started = time.monotonic()
    await asyncio.wait_for(asyncio.gather(a.join(), b.join()), 30)
    connected = time.monotonic() - started
    await asyncio.sleep(3)  # let streams start (and simulcast settle on 3G)
    rates = await flowing(a, b)
    # 100 audio frames/s at 10 ms each; require most of them, and some video.
    ok = all(r["audio"] >= 80 and r["video"] >= 3 for r in rates.values())
    check(f"call connects and flows on {profile}", ok, f"joined in {connected:.1f}s, rx/s {rates}")
    return a, b


async def main(tokens):
    netem(None)
    # 0. SF-2 first, on a clean network: the agent shares LiveKit's network namespace,
    #    so the shaped scenarios below would slow it down too.
    await moderation(tokens)

    # 1. 4G and 3G
    a, b = await call_on("4g", tokens["video"])
    await a.leave()
    await b.leave()
    a, b = await call_on("3g", tokens["video"])

    # 2. mute and camera-off (on 3G)
    a.audio_track.mute()
    await asyncio.sleep(2)
    check("mute is seen by the other side", any(e == "peer_muted" for _, e in b.events))
    a.audio_track.unmute()
    await a.room.local_participant.unpublish_track(a.video_pub.sid)
    await asyncio.sleep(2)
    stale = time.monotonic() - b.last_frame["video"]
    check(
        "camera off is seen by the other side",
        any(e == "peer_unpublished" for _, e in b.events) and stale > 1,
        f"no video for {stale:.1f}s",
    )
    await a.publish_camera()

    # 3. drops: a short one (5 s) and one long enough to break the connection (15 s);
    #    measure how fast audio flows both ways once the network is back.
    for outage in (5, 15):
        events_before = len(a.events)
        netem("blackout")
        await asyncio.sleep(outage)
        restored = time.monotonic()
        netem("3g")
        back = None
        while time.monotonic() < restored + 20:
            fresh = restored + 0.5
            if a.last_frame["audio"] > fresh and b.last_frame["audio"] > fresh:
                back = time.monotonic() - restored
                break
            await asyncio.sleep(0.2)
        # Not just a blip: 12 s after the network returns, both must still be connected
        # with audio flowing (a failed signal resume shows up only after a few seconds).
        await asyncio.sleep(max(0, restored + 12 - time.monotonic()))
        steady = await flowing(a, b, seconds=2)
        stable = a.connected and b.connected and all(v["audio"] >= 80 for v in steady.values())
        seen = [e for _, e in a.events[events_before:]] + [
            f"B:{e}" for _, e in b.events[events_before:]
        ]
        check(
            f"{outage}s drop: back within 10 s and still connected",
            back is not None and back <= 10 and stable,
            (f"audio both ways after {back:.1f}s" if back else "not back after 20s")
            + f"; stable={stable} {steady}; events {seen}",
        )
    await a.leave()
    await b.leave()
    netem(None)

    # 4. voice token: microphone only
    voice = Peer("V", tokens["voice"]["a"], video=False)
    await voice.join()
    try:
        await asyncio.wait_for(voice.publish_camera(), 10)
        refused = False
    except Exception as e:  # noqa: BLE001
        refused = True
        print(f"      (camera refused: {type(e).__name__}: {e})")
    check("voice token cannot publish camera (FR-14)", refused)
    await voice.leave()


MAGENTA = bytes([255, 0, 255, 255]) * (W * H)
API = "http://api:8000"


def console_report(session_id: str, creds: dict) -> dict | None:
    import urllib.request

    def call(path, body=None, token=None):
        req = urllib.request.Request(
            API + path,
            data=json.dumps(body).encode() if body else None,
            headers={
                "Content-Type": "application/json",
                **({"Authorization": f"Bearer {token}"} if token else {}),
            },
        )
        with urllib.request.urlopen(req, timeout=10) as res:
            return json.load(res)

    token = call("/admin-api/auth/login", creds)["access"]
    rows = call("/admin-api/reports?automatic=true", token=token)["results"]
    for row in rows:
        if row["session_id"] == session_id and row["reason"] == "nudity":
            return call(f"/admin-api/reports/{row['id']}", token=token)
    return None


async def moderation(tokens):
    t = tokens["moderation"]
    a, b = Peer("A", t["a"]), Peer("B", t["b"])
    await asyncio.wait_for(asyncio.gather(a.join(), b.join()), 30)
    await asyncio.sleep(4)  # the agent joins and starts sampling
    flowing_before = time.monotonic() - a.last_frame["video"] < 1
    injected = time.monotonic()
    b.inject = MAGENTA
    hidden = None
    while time.monotonic() < injected + 10:
        cut = [
            ts
            for ts, e in a.events
            if ts > injected and e in ("peer_muted", "peer_unpublished", "room_closed")
        ]
        if cut:
            hidden = min(cut) - injected
            break
        await asyncio.sleep(0.05)
    check(
        "explicit test image hidden from the other person within 2 s (SF-2)",
        flowing_before and hidden is not None and hidden <= 2,
        f"hidden after {hidden:.2f}s" if hidden is not None else "not hidden within 10 s",
    )
    await asyncio.sleep(2)  # report + evidence written
    detail = console_report(t["session"], tokens["console"])
    frames = len(detail["evidence"]["frames"]) if detail else 0
    check(
        "automatic report in the moderator console with evidence",
        detail is not None and frames > 0,
        f"report {detail['id'][:8]}… with {frames} frames" if detail else "no report found",
    )
    for p in (a, b):
        p.leaving = True
        await p.leave()


if __name__ == "__main__":
    tokens = json.loads(sys.stdin.read())
    try:
        asyncio.run(main(tokens))
    finally:
        netem(None)
    failed = [n for n, ok, _ in results if not ok]
    print(f"\n{len(results) - len(failed)}/{len(results)} passed")
    sys.exit(1 if failed else 0)
