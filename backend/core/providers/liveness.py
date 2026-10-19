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
