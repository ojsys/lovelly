from abc import ABC, abstractmethod
from dataclasses import dataclass

from django.conf import settings


@dataclass(frozen=True)
class LivenessResult:
    passed: bool
    score: float
    estimated_age: int | None = None


class LivenessProvider(ABC):
    """Checks that two selfie poses show the same live person (FR-4) and estimates age (SF-3).

    `reference` is a previously verified face to compare against, when one exists.
    """

    @abstractmethod
    def check(self, poses: list[bytes], reference: bytes | None = None) -> LivenessResult: ...

    @abstractmethod
    def enroll(self, face: bytes) -> str:
        """Stores a face template from a passed selfie; returns its id."""

    @abstractmethod
    def matches(self, template_id: str, photo: bytes) -> bool:
        """Does this photo show the enrolled face? (main photo must, FR-4)"""


class FakeLivenessProvider(LivenessProvider):
    """Outcome set by settings.FAKE_LIVENESS: pass | fail | underage."""

    def check(self, poses: list[bytes], reference: bytes | None = None) -> LivenessResult:
        match settings.FAKE_LIVENESS:
            case "fail":
                return LivenessResult(passed=False, score=0.2, estimated_age=25)
            case "underage":
                return LivenessResult(passed=True, score=0.97, estimated_age=15)
            case _:
                return LivenessResult(passed=True, score=0.99, estimated_age=25)

    def enroll(self, face: bytes) -> str:
        import hashlib

        return "fake-template:" + hashlib.sha1(face).hexdigest()[:12]

    def matches(self, template_id: str, photo: bytes) -> bool:
        """Test marker: a yellow image is someone else's face."""
        return not _is_yellow(photo)


def _is_yellow(jpeg: bytes) -> bool:
    import io

    from PIL import Image, ImageStat

    r, g, b = ImageStat.Stat(Image.open(io.BytesIO(jpeg)).convert("RGB").resize((8, 8))).mean
    return r > 200 and g > 200 and b < 70
