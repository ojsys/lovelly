"""LiveKit rooms and join tokens (PRD: Media; FR-10, FR-14)."""

import logging
from abc import ABC, abstractmethod
from datetime import timedelta

from asgiref.sync import async_to_sync
from django.conf import settings

logger = logging.getLogger(__name__)

CAMERA, MICROPHONE = "camera", "microphone"


class MediaProvider(ABC):
    @property
    @abstractmethod
    def client_url(self) -> str:
        """URL the app connects to (ws/wss)."""

    @abstractmethod
    def join_token(
        self, room_name: str, identity: str, sources: list[str], ttl_seconds: int
    ) -> str: ...

    @abstractmethod
    def grant_sources(self, room_name: str, identities: list[str], sources: list[str]) -> None:
        """Change what participants already in the room may publish (voice → video)."""

    @abstractmethod
    def close_room(self, room_name: str) -> None:
        """Delete the room, disconnecting everyone in it."""


class FakeMediaProvider(MediaProvider):
    """Records calls; tokens are readable strings."""

    log: list[tuple] = []

    @property
    def client_url(self) -> str:
        return "ws://media.test"

    def join_token(self, room_name, identity, sources, ttl_seconds):
        self.log.append(("token", room_name, identity, tuple(sources)))
        return f"fake-token:{room_name}:{identity}:{','.join(sources)}"

    def grant_sources(self, room_name, identities, sources):
        self.log.append(("grant", room_name, tuple(identities), tuple(sources)))

    def close_room(self, room_name):
        self.log.append(("close", room_name))


class LiveKitMediaProvider(MediaProvider):
    """Self-hosted LiveKit SFU (infra/livekit.yaml)."""

    @property
    def client_url(self) -> str:
        return settings.LIVEKIT_URL

    def join_token(self, room_name, identity, sources, ttl_seconds):
        from livekit import api

        return (
            api.AccessToken(settings.LIVEKIT_API_KEY, settings.LIVEKIT_API_SECRET)
            .with_identity(identity)
            .with_ttl(timedelta(seconds=ttl_seconds))
            .with_grants(
                api.VideoGrants(
                    room_join=True,
                    room=room_name,
                    can_publish=True,
                    can_subscribe=True,
                    can_publish_data=False,
                    can_publish_sources=sources,
                )
            )
            .to_jwt()
        )

    def grant_sources(self, room_name, identities, sources):
        from livekit import api

        track_sources = [getattr(api.TrackSource, s.upper()) for s in sources]

        async def run():
            async with self._api() as lk:
                for identity in identities:
                    await lk.room.update_participant(
                        api.UpdateParticipantRequest(
                            room=room_name,
                            identity=identity,
                            permission=api.ParticipantPermission(
                                can_publish=True,
                                can_subscribe=True,
                                can_publish_sources=track_sources,
                            ),
                        )
                    )

        async_to_sync(run)()

    def close_room(self, room_name):
        from livekit import api

        async def run():
            async with self._api() as lk:
                await lk.room.delete_room(api.DeleteRoomRequest(room=room_name))

        try:
            async_to_sync(run)()
        except Exception:
            # The room may never have been joined; LiveKit then has nothing to delete.
            logger.info("close_room %s: nothing to close", room_name)

    def _api(self):
        from livekit import api

        return api.LiveKitAPI(
            settings.LIVEKIT_API_URL, settings.LIVEKIT_API_KEY, settings.LIVEKIT_API_SECRET
        )
