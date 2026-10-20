from celery import shared_task

from matching.service import purge_stranger_messages as _purge


@shared_task
def purge_stranger_messages() -> int:
    return _purge()
