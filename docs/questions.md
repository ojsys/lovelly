# Open questions

## From the PRD

1. Coin pack and Plus prices in naira, and the store price tier each one maps to.
2. Can a web top-up with Paystack or Flutterwave (card, bank transfer, USSD) sit alongside
   in-app purchases without breaking store rules? Needs legal or store review.
3. Which provider for liveness checks and age estimation, and which for nudity detection?
   Depends on cost per check and accuracy on African skin tones; bake-off before M1 and M4.
4. Which SMS provider, and the cost per code in Nigeria?
5. Self-hosted LiveKit or LiveKit Cloud at launch, and which hosting region is nearest Nigeria?
6. Trademark search for "Korram" in Nigeria and the app stores ("Korrma", a trading app,
   already exists).
7. Is the Nigeria Data Protection Act registration and DPIA done before beta?

## Gaps found comparing the PRD with the designs

8. **Brand name.** The designs say "kora" / "Kora Plus" / "Thanks for keeping Kora safe";
   the PRD says "Korram" / "Korram Plus". Which name ships in the UI copy?
   → **Answered 2026-10-19:** UI uses **Korram** ("korram" wordmark, "Korram Plus").
9. **No phone-number entry screen.** Welcome's "Continue with phone number" links straight to
   Verify ("Enter the code we texted you"). Where does the user type their number? Proposal:
   a small number-entry step at `/onboarding/phone` styled like Verify — needs a design or OK.
   → **Answered 2026-10-19:** add `/onboarding/phone` styled like Verify; phone + code share step 1 of 4.
10. **"Get a call instead"** on Verify implies voice-call OTP, which the PRD doesn't mention.
    Build it, or drop the link?
    → **Answered 2026-10-19:** build it (voice-call OTP via the SMS provider interface; same rate limit).
11. **Resend timer.** Verify shows "Resend code in 0:42"; PRD says resend after 60 s. Assume
    60 s countdown (0:42 is mid-countdown) — confirm.
12. **Age filter.** FR-8 mentions gender, region *and age* filters, but Home, Premium and PayGo
    only show gender and region, and the PAYG price table has no age-filter price. Is age
    filtering in the MVP?
13. **Selfie compared to "main profile photo"** (FR-4), but onboarding has no photo-upload
    step before the selfie (photos are on Profile, screen 09). Is the selfie itself the first
    main photo, or is there a photo step?
    → **Answered 2026-10-19:** the selfie is the verification reference; later main photos are face-matched against it (see plans/M1.md "Decisions to confirm" for the privacy detail).
14. **Welcome doesn't fit its own frame.** In `01-Main.dc.html` at 390 × 844 the headline wraps
    to 3 lines and the Google/Apple buttons and 18+ line are clipped off the bottom. The app
    shrinks the photo grid to make everything fit (and hides it, scrolling, on very short
    screens). Confirm that's acceptable, or supply a revised layout.

## Infrastructure notes (decided in M0, flag if you disagree)

15. **MinIO image.** MinIO no longer publishes community Docker images (`minio/minio` is gone
    from Docker Hub). Dev uses Chainguard's from-source MinIO build, pinned by digest. Production
    object storage is still open (any S3-compatible service works).
16. **Placeholder links.** Terms, Community Guidelines and Support point to
    `https://example.com/korram/...` (`app/lib/config/app_config.dart`). The app stores need
    real URLs and a published support contact before beta.
17. **Screens built without a design (M1):** phone entry, OTP error messages, selfie
    failed, "We're checking your selfie" (manual review), "We couldn't verify you"
    (rejected) and "Account removed" (under 18). Goldens are in `app/test/goldens/`; review
    the copy.

## Raised in M2 planning

18. **Text → call for strangers.** Chat (06) shows voice/video buttons and a "Let's switch to
    voice" quick reply, but the PRD only defines voice → video upgrades in calls (FR-14).
    Should a stranger text chat be able to become a call (both agree, like the upgrade)?
19. **Live online count on the searching screen** (FR-9) isn't in the Matching design; M2
    adds a small "N people online" line like Home's.
20. **Slur list for the chat filter (SF-8).** Needs a curated list covering English, Pidgin,
    Hausa, Yoruba and Igbo. M2 ships a small placeholder list in config.
21. **Interest catalogue.** The server controls the list (FR-19). M2 seeds a starter set
    (Afrobeats, Football, Tech, Poetry, Food, …) that can be edited in admin. Supply the
    real list when ready.
