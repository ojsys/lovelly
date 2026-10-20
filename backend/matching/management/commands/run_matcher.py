import logging
import signal
import time

from django.core.management.base import BaseCommand
from django.db import close_old_connections

from matching import service

logger = logging.getLogger(__name__)

TICK_SECONDS = 0.25


class Command(BaseCommand):
    help = "Dedicated matcher worker loop (PRD: Background jobs). Safe to run several."

    def handle(self, *args, **options):
        running = True

        def stop(*_):
            nonlocal running
            running = False

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        logger.info("matcher started")
        while running:
            started = time.monotonic()
            try:
                close_old_connections()
                pairs = service.run_tick()
                service.sweep_disconnects()
                took = time.monotonic() - started
                if pairs or took > TICK_SECONDS:
                    logger.info("tick: %d pairs in %.0f ms", len(pairs), took * 1000)
            except Exception:
                logger.exception("matcher tick failed")
            time.sleep(max(0.0, TICK_SECONDS - (time.monotonic() - started)))
        logger.info("matcher stopped")
