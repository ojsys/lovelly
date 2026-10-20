from celery import shared_task

from .reconcile import check_ledger as _check


@shared_task
def check_ledger() -> int:
    return len(_check())
