# App Store 1.0 Submission Pack

Repository-aligned copy and release evidence for Counting Sheep 1.0. This is a working
submission aid, not proof that an App Store Connect field has been saved.

Last read-only App Store Connect audit: **2026-07-30, Asia/Singapore**.

## Current App Store Connect state

- App: `Counting Sheep: Wind Down` (`6788186681`)
- Version 1.0: **Prepare for Submission**
- TestFlight build 2: **processed successfully** and selected for App Store version 1.0.
- Build 10 is the current local candidate and adds the Home/Nights/Farm/Settings shell;
  Farm includes a living flock, The Barn, Ollie's Search, Search Journal, and local customization,
  NFC-authenticated ending, Live Activity layout fixes, and optional-sharing/feedback flows.
  Physical retest, screenshots, privacy updates, and upload remain pending.
- No iPhone or Watch screenshots are uploaded.
- App Privacy is published and the privacy policy is live at
  `https://countingsheepproject.com/app-privacy-policy.html`.
- Product metadata is mostly prepared; screenshots, age rating, content rights, and final
  legal declarations remain.
- Manual release is selected.

## Recommended product-page fields

### Name

`Counting Sheep: Wind Down`

This updates the App Store positioning while the installed display name remains
`Counting Sheep`.

### Subtitle

`Put your phone to bed`

### Promotional text

`A gentle bedtime ritual for putting your phone away before sleep.`

### Description

Counting Sheep helps you step away from bedtime scrolling with one small, repeatable
ritual: put your phone to bed before you do.

Choose when you want to wind down and when your phone should wake. At Wind Down, carry
your iPhone to its resting place, begin the ritual, and let Ollie guard the quiet while you
do something away from the screen.

Counting Sheep includes:

• A saved wind-down and morning-quiet plan
• Optional selected-app shielding through Wind Down and sleep
• App Shielding or NFC + App Shielding; legacy timer, QR, and Watch data remain compatible
• A calm Lock Screen Live Activity while Wind Down is running
• Quiet-minute history, a factual seven-night record, and Ollie's persisted sheep-search Search Journal
• Optional Apple Health sleep duration and available sleep stages
• Private morning reflections and cautious sleep-context comparisons
• A direct feedback and support path

Only if Slumber Party is enabled for this submission, append:

`• An optional invite-only seven-night Slumber Party with positive-only shared check-ins`

NFC tags are optional. Wind Down always has a no-hardware path, and shielding always has a
gentle early exit through the registered Wind Down tag or Counting Sheep.

Detailed ritual and Health history stays on your device by default. Optional impact sharing
is separately explained and consented to. Counting Sheep does not diagnose sleep conditions
or promise that one routine caused a sleep outcome.

### Keywords

`bedtime,wind down,phone away,screen time,sleep routine,NFC,app blocker,digital wellbeing`

### URLs and category

- Support URL: `https://countingsheepproject.com/`
- Marketing URL: `https://countingsheepproject.com/`
- Privacy Policy URL: `https://countingsheepproject.com/app-privacy-policy.html`
- Recommended primary category: **Health & Fitness**
- Recommended secondary category: **Lifestyle**
- Regulated medical-device declaration: **not a regulated medical device**, subject to the
  account holder completing Apple’s jurisdiction-specific declaration.
- Made for Kids: **No**
- Content rights: the app does not stream or display third-party catalogue content; confirm
  rights to every shipped visual, font, and sound before selecting the corresponding answer.

## App Review notes

Counting Sheep is a bedtime digital-wellbeing app. It does not require an account or special
hardware for its core flow.

REVIEW PATH

1. Open Settings → Your Wind Down, choose App Shielding or NFC + App Shielding, and save the default plan.
2. Keep App Shielding selected to test without NFC, then return to Home.
3. In Settings, connect Screen Time and choose a disposable app in Apple’s Family Activity
   picker.
4. Start Wind Down. The run moves through wind-down, overnight, and morning-quiet phases
   from one persisted schedule.
5. App Shielding sessions have a direct early-end action. In NFC mode, the
   registered Wind Down tag authenticates the normal end action; a multi-step emergency exit
   remains available and immediately clears the ManagedSettings store.

FAMILY CONTROLS

Shielding is separately optional and applies only to apps/categories the reviewer selects.
It begins at the eligible start, continues through wind-down, overnight, and morning quiet,
and never shields Counting Sheep.
The embedded Device Activity monitor handles scheduled transitions while the containing app
is suspended. The shield action closes the shielded app; the reviewer can open Counting
Sheep to end Wind Down through the configured method or emergency exit.

NFC

NFC is an optional physical cue. A generic writable NDEF tag can be provisioned in Wind
Down setup, replaced, forgotten, and confirmed on later starts. The same registered tag is
required to end an NFC-protected Wind Down normally; cancelled or mismatched scans leave it
running. A clearly labelled, multi-step emergency exit remains available if the tag is lost.
The app stores a SHA-256 digest rather than the raw registration token. Choose Honor timer
or QR to review without an NFC tag.

HEALTHKIT

Health access is optional and read-only. Counting Sheep requests only
`HKCategoryTypeIdentifierSleepAnalysis` to show sleep interval, duration, and available
core/deep/REM stages alongside the user’s local Wind Down history. It does not write Health
data, calculate a medical score, or alter the flock when Health access is absent.

APPLE WATCH / NEARBY INTERACTION

Apple Watch is an optional, short Wind Down check. Unsupported or unreachable Watch hardware
falls back to the honor timer. Continuous distance monitoring is not required.

DATA

Detailed ritual, Screen Time, NFC, reflection, and Health history remains local by default.
The production backend uses anonymous authentication for optional Live Activity delivery.
Optional impact sharing has its own consent and delete controls. Its production schema and
privacy disclosures are live.

The feedback form uses private Supabase Storage and Resend only when its independent release
flag is enabled. It accepts optional reply email, selected screenshots, and a narrow
diagnostics opt-in. If that backend gate is off, the same validated draft opens in Mail.

No sign-in or demo credentials are required for the core flow or while Slumber Party is disabled.
A short physical-device video showing NFC
provisioning, continuous shielding through overnight, and early exit should be attached if
App Review cannot reproduce the hardware path.

SLUMBER PARTY (ONLY WHEN `SUPABASE_NIGHT_FLOCK_ENABLED=YES`)

Slumber Party is nested under Farm and requires Sign in with Apple to create or join. It links the
existing anonymous Supabase identity in place; it does not replace ownership or make the local
Wind Down require an account. Reviewers need two Apple-linked test accounts and a one-use invite
code to exercise the full flow. The feature shares only positive phone-tucked and completed
quiet-morning states. Active Wind Down has no social UI. There is no feed, chat, discovery,
leaderboard, reward, Farm transfer, free text, or named completion.

Keep `SUPABASE_NIGHT_FLOCK_ENABLED=NO` for App Review until the Apple capability/provider,
hosted migration and functions, retention schedule, moderation operations, public policy/App
Privacy answers, and physical two-account QA are complete. If enabled, attach review credentials
or precise invite instructions and describe the block/report/account-deletion path.

## App Privacy answers

Answer for the most data-collecting production configuration, including Supabase:

| App Store data type | Linked | Tracking | Purposes |
|---|---:|---:|---|
| Health & Fitness → Health | Yes | No | Analytics; App Functionality |
| Usage Data → Product Interaction | Yes | No | Analytics; App Functionality |
| Identifiers → User ID | Yes | No | App Functionality; Analytics |
| Identifiers → Device ID | Yes | No | App Functionality |
| Contact Info → Email Address | Yes | No | App Functionality; Customer Support |
| User Content → Customer Support / Other User Content | Yes | No | App Functionality; Customer Support |
| User Content → Photos or Videos | Yes | No | App Functionality; Customer Support |
| Diagnostics → Other Diagnostic Data | Yes | No | App Functionality; Customer Support |

Do not declare local-only HealthKit, Screen Time selections, NFC registration, or free-text
reflection as collected unless the production app or a third party transmits it. Do include
the official Supabase SDK and enabled service behavior in the answers.
If Slumber Party is enabled, include its fixed positive check-ins/reactions and safety reports under
the current App Store Connect User Content/Product Interaction taxonomy and Sign in with Apple
account identifier under User ID.

## Required screenshots

At minimum, capture truthful Release-build screens showing:

1. Home: tonight’s Wind Down plan and one primary start action.
2. Settings: Your Wind Down, Connections, and Help & app guide groups, including the secondary
   “About these ideas and sources” link.
3. Active Wind Down: calm current phase with early exit visible.
4. Nights: cumulative flock, completed quiet minutes, and seven-night history.
5. Nights: optional sleep duration/stages and the association-not-causation comparison.

The first three should explain the complete value proposition without relying on captions
that promise better sleep. Add one Watch screenshot only if the paired-Watch surface is
visually ready and accurately represents the optional role.

## Submission order

1. Confirm the published privacy policy and support/contact route remain reachable.
2. Apply the reviewed feedback migration/functions only if the full feedback release gate
   passes; otherwise keep `SUPABASE_FEEDBACK_ENABLED = NO` and verify email fallback.
3. Complete physical NFC, shielding, HealthKit, background, and early-exit QA.
4. Confirm final art rights and replace any public-repository placeholder assets.
5. Confirm the configured `ITSAppUsesNonExemptEncryption = false` answer remains accurate.
6. Upload build 10 after the physical NFC and shielding retest and wait for processing.
7. Upload screenshots; update description, review notes, category, content rights, age
   rating, regulated-device declaration, privacy policy, and App Privacy answers.
8. Select the processed build, attach the device-demonstration video, and run the final
   App Store validation.
9. Add for review only after every required field and physical QA item is complete.
