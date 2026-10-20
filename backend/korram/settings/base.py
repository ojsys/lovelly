from datetime import timedelta
from pathlib import Path

import environ

BASE_DIR = Path(__file__).resolve().parent.parent.parent

env = environ.Env()

SECRET_KEY = env("DJANGO_SECRET_KEY")
DEBUG = env.bool("DJANGO_DEBUG", default=False)
ALLOWED_HOSTS = env.list("DJANGO_ALLOWED_HOSTS", default=[])

INSTALLED_APPS = [
    "daphne",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.postgres",
    "rest_framework",
    "rest_framework_simplejwt.token_blacklist",
    "drf_spectacular",
    "channels",
    "core",
    "accounts",
    "matching",
    "chat",
    "safety",
    "wallet",
    "billing",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "korram.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "korram.wsgi.application"
ASGI_APPLICATION = "korram.asgi.application"

DATABASES = {"default": env.db("DATABASE_URL")}
# Reuse connections: opening one (with password auth) per query or per websocket event is
# far too slow under load. Health checks drop connections the server closed.
DATABASES["default"]["CONN_MAX_AGE"] = env.int("DB_CONN_MAX_AGE", default=60)
DATABASES["default"]["CONN_HEALTH_CHECKS"] = True

AUTH_USER_MODEL = "accounts.User"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

REDIS_URL = env("REDIS_URL")

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": REDIS_URL,
    }
}

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {"hosts": [REDIS_URL]},
    }
}

CELERY_BROKER_URL = REDIS_URL
CELERY_RESULT_BACKEND = REDIS_URL
CELERY_TASK_ALWAYS_EAGER = False
CELERY_BEAT_SCHEDULE = {
    "purge-stranger-messages": {
        "task": "chat.tasks.purge_stranger_messages",
        "schedule": 60 * 60 * 6,
    },
    "purge-verified-selfies": {
        "task": "accounts.tasks.purge_verified_selfies",
        "schedule": 60 * 60 * 6,
    },
}

# Private S3-compatible storage (MinIO in development). Files are served via signed URLs.
STORAGES = {
    "default": {
        "BACKEND": "storages.backends.s3.S3Storage",
        "OPTIONS": {
            "endpoint_url": env("S3_ENDPOINT_URL"),
            "access_key": env("S3_ACCESS_KEY"),
            "secret_key": env("S3_SECRET_KEY"),
            "bucket_name": env("S3_BUCKET_PHOTOS", default="photos"),
            "default_acl": "private",
            "querystring_auth": True,
            "querystring_expire": 300,
        },
    },
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}
S3_BUCKET_EVIDENCE = env("S3_BUCKET_EVIDENCE", default="evidence")

LIVEKIT_URL = env("LIVEKIT_URL", default="ws://localhost:7880")
LIVEKIT_API_KEY = env("LIVEKIT_API_KEY", default="")
LIVEKIT_API_SECRET = env("LIVEKIT_API_SECRET", default="")

# Outside providers (see core/providers). "fake" until real providers are chosen.
PROVIDERS = {
    "sms": env("PROVIDER_SMS", default="fake"),
    "identity": env("PROVIDER_IDENTITY", default="fake"),
    "liveness": env("PROVIDER_LIVENESS", default="fake"),
    "moderation": env("PROVIDER_MODERATION", default="fake"),
    "media": env("PROVIDER_MEDIA", default="fake"),
    "store_receipts": env("PROVIDER_STORE_RECEIPTS", default="fake"),
    "paystack": env("PROVIDER_PAYSTACK", default="fake"),
}

# FakeLivenessProvider outcome: pass | fail | underage (drives the M1 acceptance demo).
FAKE_LIVENESS = env("FAKE_LIVENESS", default="pass")

# Google / Apple sign-in (FR-2). Audiences the ID tokens must be issued for.
GOOGLE_CLIENT_IDS = env.list("GOOGLE_CLIENT_IDS", default=[])
APPLE_CLIENT_IDS = env.list("APPLE_CLIENT_IDS", default=[])

# SF-8 chat filter slur list: placeholder until a curated list exists (questions.md #20).
CHAT_SLUR_LIST = env.list("CHAT_SLUR_LIST", default=["slurplaceholder"])

# Onboarding rules (PRD FR-1, FR-3, FR-4; NFR Privacy).
OTP_LENGTH = 6
OTP_TTL_SECONDS = 5 * 60
OTP_MAX_PER_HOUR = 3
OTP_RESEND_SECONDS = 60
OTP_MAX_ATTEMPTS = 5
MIN_AGE = 18
SELFIE_MAX_ATTEMPTS = 3
SELFIE_RETENTION_DAYS = 30
DEFAULT_PHONE_REGION = "NG"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    # JSON only; upload views opt in to multipart. Keeps the generated Dart client on JSON.
    "DEFAULT_PARSER_CLASSES": ["rest_framework.parsers.JSONParser"],
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "EXCEPTION_HANDLER": "core.exceptions.api_exception_handler",
    "DEFAULT_THROTTLE_CLASSES": ["rest_framework.throttling.ScopedRateThrottle"],
    # Generous per-IP limits: many Nigerian users share carrier NAT addresses.
    # Per-phone limits (FR-1) are enforced in accounts.services.otp.
    "DEFAULT_THROTTLE_RATES": {
        "otp_request": "30/hour",
        "otp_verify": "60/hour",
        "social": "60/hour",
        "selfie": "20/hour",
    },
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=15),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
    "USER_ID_FIELD": "id",
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Korram API",
    "VERSION": "1.0.0",
    "SCHEMA_PATH_PREFIX": "/api/v1/",
    # Separate request/response components, so read-only and file fields generate correctly.
    "COMPONENT_SPLIT_REQUEST": True,
    "SERVE_INCLUDE_SCHEMA": False,
}

SENTRY_DSN = env("SENTRY_DSN", default="")
if SENTRY_DSN:
    import sentry_sdk

    sentry_sdk.init(dsn=SENTRY_DSN, send_default_pii=False)

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "structured": {
            "format": '{"time":"%(asctime)s","level":"%(levelname)s",'
            '"logger":"%(name)s","msg":"%(message)s"}'
        }
    },
    "handlers": {"console": {"class": "logging.StreamHandler", "formatter": "structured"}},
    "root": {"handlers": ["console"], "level": "INFO"},
}
