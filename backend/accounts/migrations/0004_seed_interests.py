from django.db import migrations

# Starter catalogue (docs/questions.md #21); edit in admin.
STARTER = [
    ("afrobeats", "Afrobeats"), ("football", "Football"), ("tech", "Tech"),
    ("poetry", "Poetry"), ("food", "Food"), ("movies", "Movies"), ("nollywood", "Nollywood"),
    ("fashion", "Fashion"), ("gaming", "Gaming"), ("travel", "Travel"), ("books", "Books"),
    ("fitness", "Fitness"), ("business", "Business"), ("art", "Art"), ("photography", "Photography"),
    ("anime", "Anime"), ("basketball", "Basketball"), ("comedy", "Comedy"), ("faith", "Faith"),
    ("music", "Music"),
]


def seed(apps, schema_editor):
    Interest = apps.get_model("accounts", "Interest")
    for slug, label in STARTER:
        Interest.objects.get_or_create(slug=slug, defaults={"label": label})


class Migration(migrations.Migration):
    dependencies = [("accounts", "0003_interest_userinterest")]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
