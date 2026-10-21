import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "lovelly.settings.dev")

app = Celery("lovelly")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
