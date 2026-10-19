from celery import shared_task

from .services.onboarding import purge_verified_selfies as _purge


@shared_task
def purge_verified_selfies() -> int:
    return _purge()
