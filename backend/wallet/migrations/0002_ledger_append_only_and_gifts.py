from django.db import migrations

SQL = """
CREATE OR REPLACE FUNCTION wallet_reject_change() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'the coin ledger is append-only (MN-2)';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER coinledger_append_only
BEFORE UPDATE OR DELETE ON wallet_coinledger
FOR EACH ROW EXECUTE FUNCTION wallet_reject_change();
"""

REVERSE = """
DROP TRIGGER IF EXISTS coinledger_append_only ON wallet_coinledger;
DROP FUNCTION IF EXISTS wallet_reject_change();
"""

# MN-5, in the order of screen 11.
GIFTS = [
    ("heart", "Heart", 5),
    ("coffee", "Coffee", 10),
    ("jollof", "Jollof", 20),
    ("star", "Star", 30),
    ("talking_drum", "Talking drum", 50),
    ("vibes", "Vibes", 80),
    ("crown", "Crown", 150),
    ("diamond", "Diamond", 300),
]


def seed(apps, schema_editor):
    Gift = apps.get_model("wallet", "Gift")
    for i, (slug, name, cost) in enumerate(GIFTS):
        Gift.objects.get_or_create(slug=slug, defaults={"name": name, "cost": cost, "sort": i})


class Migration(migrations.Migration):
    dependencies = [("wallet", "0001_initial")]
    operations = [
        migrations.RunSQL(SQL, REVERSE),
        migrations.RunPython(seed, migrations.RunPython.noop),
    ]
