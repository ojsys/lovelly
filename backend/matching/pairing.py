"""Pure pairing rules (FR-6, FR-7, FR-9). No Redis or DB here, so they're easy to test."""

from collections.abc import Callable
from dataclasses import dataclass, field

from accounts.services.regions import AFRICA

WIDEN_AFTER_SECONDS = 30
MAX_CANDIDATES = 200


@dataclass(frozen=True)
class Ticket:
    user_id: str
    mode: str
    joined_at: float
    interests: frozenset[str] = field(default_factory=frozenset)
    languages: frozenset[str] = field(default_factory=frozenset)
    city: str = ""
    # Who they are, for other people's paid filters (FR-8)…
    gender: str = ""
    country: str = ""
    state: str = ""
    # …and their own filters: "women"/"men", "nearby"/"nigeria"/"africa" (or "").
    want_gender: str = ""
    want_region: str = ""

    def waited(self, now: float) -> float:
        return now - self.joined_at

    def widened(self, now: float) -> bool:
        return self.waited(now) >= WIDEN_AFTER_SECONDS

    @property
    def has_preferences(self) -> bool:
        return bool(self.interests or self.languages)


GENDERS = {"women": "woman", "men": "man"}


def meets(a: Ticket, b: Ticket) -> bool:
    """Does `b` fit `a`'s paid filters (FR-8)? People who chose "other" only meet people
    with no gender filter."""
    if a.want_gender and b.gender != GENDERS[a.want_gender]:
        return False
    if a.want_region == "nearby":
        return bool(a.state) and b.state == a.state and b.country == "NG"
    if a.want_region == "nigeria":
        return b.country == "NG"
    if a.want_region == "africa":
        return b.country in AFRICA
    return True


def compatible(a: Ticket, b: Ticket, now: float) -> bool:
    """Paid filters always hold, both ways; they never widen (M7 decision 3). Then, before
    30 s: share an interest or a language. Users with no preferences, or anyone who has
    waited 30 s (FR-9), accept everyone."""
    if not (meets(a, b) and meets(b, a)):
        return False
    if a.widened(now) or b.widened(now):
        return True
    if not a.has_preferences or not b.has_preferences:
        return True
    return bool(a.interests & b.interests or a.languages & b.languages)


def score(a: Ticket, b: Ticket) -> tuple:
    """FR-6 order: shared interests, then shared language, then nearby (same city)."""
    return (
        len(a.interests & b.interests),
        len(a.languages & b.languages),
        int(bool(a.city) and a.city.lower() == b.city.lower()),
    )


def pick_pairs(
    tickets: list[Ticket],
    now: float,
    excluded: Callable[[str, str], bool],
    max_candidates: int = MAX_CANDIDATES,
) -> list[tuple[Ticket, Ticket]]:
    """Greedy pairing, oldest ticket first. `excluded(a, b)` covers blocks, recent matches
    and anything else that must never pair (FR-7)."""
    waiting = sorted(tickets, key=lambda t: t.joined_at)
    taken: set[str] = set()
    pairs = []
    for t in waiting:
        if t.user_id in taken:
            continue
        best, best_key = None, None
        seen = 0
        for c in waiting:
            if c.user_id == t.user_id or c.user_id in taken or c.mode != t.mode:
                continue
            seen += 1
            if seen > max_candidates:
                break
            if excluded(t.user_id, c.user_id) or not compatible(t, c, now):
                continue
            key = (*score(t, c), c.waited(now))
            if best_key is None or key > best_key:
                best, best_key = c, key
        if best:
            taken |= {t.user_id, best.user_id}
            pairs.append((t, best))
    return pairs
