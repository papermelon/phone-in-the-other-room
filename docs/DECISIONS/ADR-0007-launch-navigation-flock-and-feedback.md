# ADR-0007: Launch Navigation, Flock Progress, and Feedback Delivery

- Status: Accepted; Farm and economy sections superseded by ADR-0015
- Date: 2026-08-01
- Deciders: Founder
- Related: ADR-0003, ADR-0005, ADR-0006, `docs/PROJECT_BRIEF.md`

## Context

Farm, Friends, and Shop were visible enough in development to make the product appear
broader than the ritual being tested. Nights also mixed outcomes with setup, while Home
showed configuration controls that competed with tonight's single action. The August
candidate needs one information architecture across Debug, TestFlight, and App Store
builds, without deleting compatibility data or useful internal mock screens. Settings is a
root destination because configuration is part of the tested product, not a hidden utility.

The former keepsake and Ollie-level concepts were not connected to a real ritual. ADR-0015 now
connects the search result to a local, transparent Farm lifecycle and economy.
Testers still need a direct, privacy-bounded way to report problems, but backend readiness must
not block submission.

## Decision

### Launch shell

All ordinary builds use exactly four root destinations:

1. **Home** — tonight's saved plan, Ollie, the person's quiet-time purpose, one primary
   Set/Start Wind Down action, a clickable schedule editor, and a compact one-time Wind Down card.
2. **Nights** — a finite, observational record: latest result, flock total, seven-night
   history, morning reflection, Apple Health context, and Screen Time results.
3. **Farm** — the real-data pasture, The Barn, Ollie's Search, Farm Shop, and Search Journal.
4. **Settings** — the Wind Down plan, App Shielding choice, connections, privacy, help, and app information.

The old More utility sheet and top-bar ellipsis are removed. Friends and the legacy Farm/Shop/
shelf mock screens are reachable only from Settings when launched with
`-ollie.debug.enableMockScreens YES`; they are not shown as locked or coming soon. The production
Farm Shop is a distinct real-data destination nested under Farm.

### Ollie's search

Every persisted successful search outcome creates an individual Farm arrival. Farm separates
owned `FlockSheep` inventory from permanent catalogue discovery and Search Journal history. Rarity
affects wool yield, regrowth, and trade value as specified by ADR-0015.

`UserProgress.totalCompletedRuns` remains the protected-night count. Search outcomes and found
sheep identities live in `SheepSearchState`; early-ended sessions do not advance the search.

Legacy `RewardItem`, balance, coin, and Ollie-level fields remain decodable for compatibility,
but the new wool balance is a clean field in `FarmState`. The old shelf remains an
explicit internal preview.

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

## Superseding Farm decision

ADR-0015 authorizes the production Farm lifecycle, wool economy, nested Shop, and local
customization. It does not authorize mock missions or social features. Friends remains gated and
requires its own ADR, backend, moderation, and belonging-test approval.

## Consequences

- Debug accurately represents the release surface unless internal previews are explicitly
  requested.
- Setup has one finite home in Settings, while Nights can be evaluated as an outcome record.
- Existing persisted data remains safe, but compatibility fields and gated screens retain
  a maintenance cost until a later cleanup.
- Feedback can improve TestFlight learning without becoming an App Store launch dependency.
- App Store screenshots, review notes, privacy answers, and the public policy must describe
  the four-tab shell and optional feedback collection.
