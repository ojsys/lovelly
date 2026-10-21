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


# --- Paid filters (FR-8, M7) --------------------------------------------------------------


def who(
    uid, gender="woman", country="NG", state="lagos", want_gender="", want_region="", waited=1.0
):
    return Ticket(
        user_id=uid,
        mode="text",
        joined_at=NOW - waited,
        gender=gender,
        country=country,
        state=state,
        want_gender=want_gender,
        want_region=want_region,
    )


def test_fr8_gender_filter_is_met_by_the_other_person():
    seeker = who("a", gender="man", want_gender="women")
    assert compatible(seeker, who("b", gender="woman"), NOW)
    assert not compatible(seeker, who("c", gender="man"), NOW)
    assert not compatible(seeker, who("d", gender="other"), NOW)  # "other": no-filter only


def test_fr8_both_peoples_filters_must_hold():
    a = who("a", gender="man", want_gender="women")
    b = who("b", gender="woman", want_gender="women")
    assert not compatible(a, b, NOW)


def test_fr8_regions():
    lagos, abuja = who("l", state="lagos"), who("f", state="fct")
    ghana = who("g", country="GH", state="")
    uk = who("u", country="GB", state="")
    nearby = who("n", state="lagos", want_region="nearby")
    assert compatible(nearby, lagos, NOW) and not compatible(nearby, abuja, NOW)
    nigeria = who("ng", want_region="nigeria")
    assert compatible(nigeria, abuja, NOW) and not compatible(nigeria, ghana, NOW)
    africa = who("af", want_region="africa")
    assert compatible(africa, ghana, NOW) and not compatible(africa, uk, NOW)


def test_m7_paid_filters_never_widen():
    seeker = who("a", gender="man", want_gender="women", waited=600)
    assert not compatible(seeker, who("b", gender="man", waited=600), NOW)


def test_fr8_pick_pairs_skips_people_who_dont_fit():
    seeker = who("a", gender="man", want_gender="women", waited=10)
    man, woman = who("m", gender="man", waited=9), who("w", gender="woman", waited=1)
    pairs = pick_pairs([seeker, man, woman], NOW, never)
    assert {(x.user_id, y.user_id) for x, y in pairs} == {("a", "w")}
