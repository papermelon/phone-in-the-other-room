# ADR-0007: Launch Navigation, Flock Progress, and Feedback Delivery

- Status: Accepted
- Date: 2026-08-01
- Deciders: Founder
- Related: ADR-0003, ADR-0005, ADR-0006, `docs/PROJECT_BRIEF.md`

## Context

Farm, Friends, and Shop were visible enough in development to make the product appear
broader than the ritual being tested. Nights also mixed outcomes with setup, while Home
showed configuration controls that competed with tonight's single action. The August
candidate needs one information architecture across Debug, TestFlight, and App Store
builds, without deleting compatibility data or useful internal mock screens.

The former keepsake, sheep-currency, coin, and Ollie-level concepts were not connected to a
real ritual. The updated direction makes Ollie's search, wanted posters, and cosmetic rarity
part of the bedtime habit loop while keeping the result local, transparent, and non-functional.
Testers still need a direct, privacy-bounded way to report problems, but backend readiness must
not block submission.

## Decision

### Launch shell

All ordinary builds use exactly three root destinations:

1. **Home** — tonight's saved plan, Ollie, the person's quiet-time purpose, one primary
   Set/Start Wind Down action, and one Edit Plan action.
2. **Nights** — a finite, observational record: latest result, flock total, seven-night
   history, morning reflection, Apple Health context, and Screen Time results.
3. **Farm** — the real-data flock presentation, one equal sheep per protected primary night.

More opens from the Home top-right utility button and contains Wind Down configuration,
connections, data and privacy, help, feedback, and app information. Friends, Shop, and the
legacy Farm/shelf mock screens are reachable only from More when launched with
`-ollie.debug.enableMockScreens YES`; they are not shown as locked or coming soon.

### Ollie's search

The release presentation uses `UserProgress.totalCompletedRuns` as the flock count: each
completed primary protected night settles one equal sheep. Farm also reads the compatible
sheep-search field book to render the finite Missing Posters board; poster identity, rarity, and
trail context are cosmetic/story context only and never alter the equal sheep value.

`UserProgress.totalCompletedRuns` remains the protected-night count. Search outcomes and found
sheep identities live in `SheepSearchState`; early-ended sessions do not advance the search.

`RewardItem`, balances, coins, rarity, and Ollie-level fields remain persisted and continue
decoding for compatibility. The August release UI does not read them. The old shelf remains
an explicit internal preview until a later migration decision.

### Feedback delivery

The feedback form accepts a category, 10–4,000 character message, optional reply email,
up to three metadata-stripped JPEG screenshots, and a narrowly defined diagnostics opt-in.
It never includes logs, Health data, Screen Time selections, schedules, NFC data, run IDs,
or persistent device identifiers.

When `SUPABASE_FEEDBACK_ENABLED` is enabled, an anonymous authenticated account uploads
screenshots into the private `feedback-attachments` bucket and submits an idempotent UUID
to the authenticated `submit-feedback` Edge Function. The database accepts at most five
submissions per rolling 24 hours per account. A report is stored before Resend notification
is attempted. Failed notifications remain pending and a secret-protected scheduled function
retries them every ten minutes, up to five attempts. Rows and attachments are purged after
180 days.

The release flag stays off until migration, private storage, delivery, retry, privacy, and
physical-device checks pass. With it off, the validated form opens the same draft and
screenshots in Mail. If Mail is unavailable, the app displays and copies
`countingsheep.sg@gmail.com`.

## Post-launch gate

After at least two stable weeks and the retention and qualitative gates in ADR-0003, the
shipping Farm can be expanded internally from the same flock count and poster board. It must
not revive currency, sheep power, or mock missions. Shop can only be nested in Farm. Friends
remains last-or-never and requires its own ADR, backend, moderation, and belonging-test approval.

## Consequences

- Debug accurately represents the release surface unless internal previews are explicitly
  requested.
- Setup has one finite home in More, while Nights can be evaluated as an outcome record.
- Existing persisted data remains safe, but compatibility fields and gated screens retain
  a maintenance cost until a later cleanup.
- Feedback can improve TestFlight learning without becoming an App Store launch dependency.
- App Store screenshots, review notes, privacy answers, and the public policy must describe
  the three-tab shell and optional feedback collection.
