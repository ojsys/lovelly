import importlib

import pytest


@pytest.fixture(autouse=True)
def gift_catalogue(db):
    """Transactional tests flush the migration's seeded gifts; put them back."""
    from wallet.models import Gift

    seed = importlib.import_module("wallet.migrations.0002_ledger_append_only_and_gifts")
    for i, (slug, name, cost) in enumerate(seed.GIFTS):
        Gift.objects.get_or_create(slug=slug, defaults={"name": name, "cost": cost, "sort": i})
