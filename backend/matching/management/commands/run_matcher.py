import logging
import signal
import time

from django.core.management.base import BaseCommand

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "Dedicated matcher worker loop. Pairing logic arrives in M2."

    def handle(self, *args, **options):
        running = True

        def stop(*_):
            nonlocal running
            running = False

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        logger.info("matcher started")
        while running:
            time.sleep(1)
        logger.info("matcher stopped")
