import pytest
from django.db import IntegrityError

from accounts.models import User

pytestmark = pytest.mark.django_db


def test_fr1_one_account_per_phone_number():
    User.objects.create_user("+2348030000002")
    with pytest.raises(IntegrityError):
        User.objects.create_user("+2348030000002")


def test_app_users_have_no_usable_password():
    assert not User.objects.create_user("+2348030000003").has_usable_password()
