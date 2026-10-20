from matching.pairing import Ticket, compatible, pick_pairs

NOW = 1_000.0


def t(uid, waited=1.0, mode="text", interests=(), languages=(), city=""):
    return Ticket(uid, mode, NOW - waited, frozenset(interests), frozenset(languages), city)


def never(a, b):
    return False


def test_fr6_pairs_only_within_the_same_mode():
    pairs = pick_pairs([t("a", mode="video"), t("b", mode="voice")], NOW, never)
    assert pairs == []


def test_fr6_prefers_shared_interests_then_language_then_city():
    me = t("me", waited=5, interests={"football"}, languages={"en"}, city="Lagos")
    city_only = t("city", languages={"en"}, city="Lagos")
    language = t("lang", languages={"en", "yo"})
    interest = t("int", interests={"football"})
    (pair,) = pick_pairs([me, city_only, language, interest], NOW, never)[:1]
    assert {pair[0].user_id, pair[1].user_id} == {"me", "int"}


def test_fr6_language_beats_city_when_no_interest_is_shared():
    me = t("me", waited=5, languages={"en", "ha"}, city="Kano")
    same_city = t("c", languages={"en"}, city="Kano")
    two_langs = t("l", languages={"en", "ha"})
    (pair,) = pick_pairs([me, same_city, two_langs], NOW, never)[:1]
    assert pair[1].user_id == "l"


def test_fr9_before_30s_needs_something_in_common():
    a = t("a", interests={"football"}, languages={"en"})
    b = t("b", interests={"poetry"}, languages={"fr"})
    assert not compatible(a, b, NOW)
    assert pick_pairs([a, b], NOW, never) == []


def test_fr9_after_30s_the_search_widens_to_anyone():
    a = t("a", waited=31, interests={"football"}, languages={"en"})
    b = t("b", interests={"poetry"}, languages={"fr"})
    assert len(pick_pairs([a, b], NOW, never)) == 1


def test_users_without_preferences_match_anyone():
    a = t("a")
    b = t("b", interests={"poetry"}, languages={"fr"})
    assert len(pick_pairs([a, b], NOW, never)) == 1


def test_fr7_excluded_pairs_never_pair_even_after_widening():
    a, b = t("a", waited=120), t("b", waited=120)
    assert pick_pairs([a, b], NOW, lambda x, y: {x, y} == {"a", "b"}) == []


def test_each_user_is_in_at_most_one_pair():
    pairs = pick_pairs([t(str(i), waited=i) for i in range(7)], NOW, never)
    ids = [u.user_id for p in pairs for u in p]
    assert len(pairs) == 3 and len(ids) == len(set(ids))


def test_oldest_waiting_user_is_served_first():
    pairs = pick_pairs([t("new", waited=1), t("old", waited=20), t("mid", waited=10)], NOW, never)
    assert pairs[0][0].user_id == "old"
