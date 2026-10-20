from django.core.management.base import BaseCommand, CommandError

from wallet.reconcile import check_ledger


class Command(BaseCommand):
    help = "Checks purchases, gifts and balances against the coin ledger (MN-2)."

    def handle(self, *args, **options):
        findings = check_ledger()
        if findings:
            raise CommandError(f"{len(findings)} ledger mismatch(es):\n" + "\n".join(findings))
        self.stdout.write("ledger OK")
