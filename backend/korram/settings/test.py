import os

os.environ.setdefault("DJANGO_SECRET_KEY", "test-only-insecure-secret-key-0123456789abcdef")
os.environ.setdefault("DATABASE_URL", "postgres://korram:korram@localhost:5433/korram")
os.environ.setdefault("REDIS_URL", "redis://localhost:6380/0")
os.environ.setdefault("S3_ENDPOINT_URL", "http://localhost:9000")
os.environ.setdefault("S3_ACCESS_KEY", "test")
os.environ.setdefault("S3_SECRET_KEY", "test")

from .base import *  # noqa: E402, F403

# Tests flush Redis, so always use a separate database (15), never the dev data in 0.
REDIS_URL = REDIS_URL.rsplit("/", 1)[0] + "/15"  # noqa: F405

PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
CHANNEL_LAYERS = {"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}}
CELERY_TASK_ALWAYS_EAGER = True
ALLOWED_HOSTS = ["localhost", "testserver"]
CACHES = {"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}}
MEDIA_URL = "/media/"
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.InMemoryStorage"},
    "evidence": {"BACKEND": "django.core.files.storage.InMemoryStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}

# Persistent connections from websocket test threads would block dropping the test DB.
DATABASES["default"]["CONN_MAX_AGE"] = 0  # noqa: F405

# Tests never talk to real outside providers, whatever the environment says.
PROVIDERS = {kind: "fake" for kind in PROVIDERS}  # noqa: F405
