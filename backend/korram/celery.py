import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "korram.settings.dev")

app = Celery("korram")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
