# Lovelly — working rules

Lovelly is a random video/voice/text connect app for verified adults (18+), Nigeria first.
The full spec is `docs/PRD.md`. UI designs are in `design/screens/*.dc.html` (390×844 frames;
both are confidential and git-ignored, so they exist only on team machines;
open one in a browser; `{{...}}` are template bindings, `[brackets]` are placeholder data that
must come from the API).

## Repo layout

- `backend/` — Django 5, DRF, Channels, Celery (PostgreSQL 16, Redis)
- `app/` — Flutter 3, Riverpod, go_router, livekit_client, dio
- `admin/` — React + Vite moderator console
- `infra/` — Docker Compose (Postgres, Redis, LiveKit, MinIO)
- `docs/` — PRD, milestone plans (`docs/plans/Mx.md`), open questions (`docs/questions.md`)

## Rules

- Work one milestone at a time, in the order of the PRD Build plan (M0 → M7). Before writing
  code for a milestone, write a short plan in `docs/plans/Mx.md` and wait for approval.
- The designs are the spec for the interface. Match spacing, sizes, copy and colours from the
  design screens.
- Colours: background `#0F0E13`, surface `#1B1A22`, line `#34313F`, text `#F4F1EA`, muted text
  `#A9A4B6`, coral `#FF6B4A`, gold `#FFC94A`, lilac `#B9A7FF`, mint `#5BE3A1`, danger `#E5484D`.
  Fonts: Bricolage Grotesque for headings, DM Sans for body text. Keep them as Flutter theme
  tokens; never hard-code them in widgets.
- Put business rules (matching, charges, cap, holds) in a backend service layer with unit
  tests. Never compute coin costs in the app; the app asks the server for a quote.
- Every coin write goes through one function, `wallet.post_entry()`, with an idempotency key.
  No other code writes to the ledger.
- Hide each outside provider behind an interface with a fake version for tests: SMS, liveness
  check, moderation, LiveKit, store receipts, Paystack.
- Name requirement IDs (FR-, SF-, MN-) in test names and commit messages.
- Don't add features that aren't in the PRD. Raise any gap as a question in
  `docs/questions.md`.
