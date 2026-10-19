from abc import ABC, abstractmethod


class MediaProvider(ABC):
    """LiveKit rooms and join tokens."""

    @abstractmethod
    def join_token(self, room_name: str, identity: str, ttl_seconds: int) -> str: ...


class FakeMediaProvider(MediaProvider):
    def join_token(self, room_name: str, identity: str, ttl_seconds: int) -> str:
        return f"fake-token:{room_name}:{identity}"
