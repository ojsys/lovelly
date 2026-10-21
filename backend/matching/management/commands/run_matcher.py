import logging
import signal
import time

from django.core.management.base import BaseCommand
from django.db import close_old_connections

from matching import friend_calls, pricing, service

logger = logging.getLogger(__name__)

TICK_SECONDS = 0.25
ORPHAN_SWEEP_TICKS = 120  # about every 30 s (4 ticks a second)


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
        ticks = 0
        while running:
            started = time.monotonic()
            try:
                close_old_connections()
                pairs = service.run_tick()
                matched = time.monotonic()
                swept = service.sweep_disconnects()
                friend_calls.sweep_missed()
                pricing.sweep_charges()  # MN-8: take holds of matches that ran 5 s
                ticks += 1
                if ticks % ORPHAN_SWEEP_TICKS == 0:
                    service.sweep_orphans()
                took = time.monotonic() - started
                if pairs or took > TICK_SECONDS:
                    # Split timing: matching vs ending dropped sessions (which calls LiveKit).
                    logger.info(
                        "tick: %d pairs in %.0f ms (match %.0f ms, sweep %d in %.0f ms)",
                        len(pairs),
                        took * 1000,
                        (matched - started) * 1000,
                        swept,
                        (time.monotonic() - matched) * 1000,
                    )
            except Exception:
                logger.exception("matcher tick failed")
            time.sleep(max(0.0, TICK_SECONDS - (time.monotonic() - started)))
        logger.info("matcher stopped")
