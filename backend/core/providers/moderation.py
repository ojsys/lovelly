"""Frame moderation (SF-2 nudity, SF-3 age). The real provider follows the bake-off
(docs/questions.md #3); the fake recognises marker images used by tests."""

import io
from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass(frozen=True)
class FrameVerdict:
    nudity: float  # 0..1 confidence
    estimated_age: int | None = None


class ModerationProvider(ABC):
    @abstractmethod
    def scan_frame(self, jpeg: bytes) -> FrameVerdict: ...


def _mean_rgb(jpeg: bytes) -> tuple[float, float, float]:
    from PIL import Image, ImageStat

    img = Image.open(io.BytesIO(jpeg)).convert("RGB").resize((16, 16))
    return tuple(ImageStat.Stat(img).mean)


class FakeModerationProvider(ModerationProvider):
    """Test markers instead of real imagery: a magenta frame counts as explicit, a cyan
    frame as someone under 18. Anything else is clean."""

    def scan_frame(self, jpeg: bytes) -> FrameVerdict:
        r, g, b = _mean_rgb(jpeg)
        if r > 200 and g < 70 and b > 200:
            return FrameVerdict(nudity=0.99, estimated_age=25)
        if r < 70 and g > 200 and b > 200:
            return FrameVerdict(nudity=0.0, estimated_age=15)
        return FrameVerdict(nudity=0.0, estimated_age=25)
