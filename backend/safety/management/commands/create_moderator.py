from django.contrib.auth.models import Group
from django.core.management.base import BaseCommand

from accounts.models import User
from safety.admin_api import MODERATORS


class Command(BaseCommand):
    help = "Create (or update) a moderator console login: create_moderator +234... password"

    def add_arguments(self, parser):
        parser.add_argument("phone")
        parser.add_argument("password")

    def handle(self, phone, password, **opts):
        user = User.objects.filter(phone=phone).first() or User.objects.create_user(phone=phone)
        user.is_staff = True
        user.set_password(password)
        user.save()
        user.groups.add(Group.objects.get_or_create(name=MODERATORS)[0])
        self.stdout.write(f"moderator {phone} ready")
