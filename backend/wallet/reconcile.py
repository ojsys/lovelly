"""Ledger checks (MN-2; NFR Observability: "ledger mismatches"). Run nightly and on demand."""

import logging

from django.db.models import Count, Q, Sum

from billing.models import Purchase
from billing.services import pack

from .models import CoinLedger, GiftSend

logger = logging.getLogger(__name__)
R = CoinLedger.Reason
S = Purchase.Status


def check_ledger() -> list[str]:
    """Every finding is a money bug; none is expected."""
    findings: list[str] = []
    entries = CoinLedger.objects

    # Purchases: credited and refunded ones carry exactly their pack; others carry nothing.
    for p in Purchase.objects.all().iterator():
        rows = entries.filter(ref_type="purchase", ref_id=str(p.id))
        credited = rows.filter(reason__in=[R.PURCHASE, R.PURCHASE_BONUS]).aggregate(
            n=Count("id"), s=Sum("delta")
        )
        refunded = rows.filter(reason=R.REFUND).aggregate(s=Sum("delta"))["s"] or 0
        want = pack(p.product_id).coins if p.status in (S.CREDITED, S.REFUNDED) else 0
        if (credited["s"] or 0) != want:
            findings.append(f"purchase {p.id} credited {credited['s'] or 0}, expected {want}")
        if p.status == S.REFUNDED and want and refunded != -want:
            findings.append(f"purchase {p.id} refunded {refunded}, expected {-want}")
        if p.status != S.REFUNDED and refunded:
            findings.append(f"purchase {p.id} has refund rows but isn't refunded")

    # Gifts: one debit each, at the price recorded with the gift.
    for g in GiftSend.objects.select_related("ledger_entry").iterator():
        e = g.ledger_entry
        if (e.reason, e.delta, e.user_id) != (R.GIFT, -g.cost, g.sender_id):
            findings.append(f"gift {g.id} debited {e.delta} ({e.reason}), expected {-g.cost}")
    orphans = entries.filter(reason=R.GIFT, giftsend__isnull=True).count()
    if orphans:
        findings.append(f"{orphans} gift debits with no gift")

    # Only refunds may take a balance below zero.
    negative = (
        entries.values("user_id")
        .annotate(b=Sum("delta"), refunds=Count("id", filter=Q(reason=R.REFUND)))
        .filter(b__lt=0, refunds=0)
    )
    findings += [f"user {n['user_id']} balance {n['b']} with no refund" for n in negative]

    for f in findings:
        logger.error("ledger mismatch: %s", f)
    return findings
