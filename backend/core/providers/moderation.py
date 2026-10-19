from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass(frozen=True)
class FrameVerdict:
    nudity: float
    estimated_age: int | None = None


class ModerationProvider(ABC):
    @abstractmethod
    def scan_frame(self, image: bytes) -> FrameVerdict: ...


class FakeModerationProvider(ModerationProvider):
    def scan_frame(self, image: bytes) -> FrameVerdict:
        return FrameVerdict(nudity=0.0, estimated_age=25)
