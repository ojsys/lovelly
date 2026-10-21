"""Where people are, for the paid region filter (FR-8, M7 decision 1).

Country comes from the verified phone number; "nearby" is the same Nigerian state, which
people pick on their profile.
"""

import phonenumbers

# The 36 states and the FCT, as slugs (shown with their names in the app).
NIGERIAN_STATES = {
    "abia": "Abia", "adamawa": "Adamawa", "akwa_ibom": "Akwa Ibom", "anambra": "Anambra",
    "bauchi": "Bauchi", "bayelsa": "Bayelsa", "benue": "Benue", "borno": "Borno",
    "cross_river": "Cross River", "delta": "Delta", "ebonyi": "Ebonyi", "edo": "Edo",
    "ekiti": "Ekiti", "enugu": "Enugu", "fct": "FCT (Abuja)", "gombe": "Gombe", "imo": "Imo",
    "jigawa": "Jigawa", "kaduna": "Kaduna", "kano": "Kano", "katsina": "Katsina",
    "kebbi": "Kebbi", "kogi": "Kogi", "kwara": "Kwara", "lagos": "Lagos",
    "nasarawa": "Nasarawa", "niger": "Niger", "ogun": "Ogun", "ondo": "Ondo", "osun": "Osun",
    "oyo": "Oyo", "plateau": "Plateau", "rivers": "Rivers", "sokoto": "Sokoto",
    "taraba": "Taraba", "yobe": "Yobe", "zamfara": "Zamfara",
}  # fmt: skip

# ISO 3166 codes of African countries and territories.
AFRICA = frozenset(
    "DZ AO BJ BW BF BI CV CM CF TD KM CG CD CI DJ EG GQ ER SZ ET GA GM GH GN GW KE LS LR LY "
    "MG MW ML MR MU YT MA MZ NA NE NG RE RW SH ST SN SC SL SO ZA SS SD TZ TG TN UG EH ZM ZW".split()
)


def country_of(phone: str) -> str:
    """ISO code of the phone number's country ("" if unknown)."""
    try:
        return phonenumbers.region_code_for_number(phonenumbers.parse(phone, None)) or ""
    except phonenumbers.NumberParseException:
        return ""
