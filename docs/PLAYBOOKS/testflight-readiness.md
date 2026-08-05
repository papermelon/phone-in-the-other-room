# Playbook: App Store 1.0 Readiness

Prepare Counting Sheep 1.0 for TestFlight and App Store review. Product scope is fixed by
`PROJECT_BRIEF.md` and ADR-0003/0004/0006/0007: four Release tabs, one user-facing Wind Down
ritual, optional NFC and continuous shielding, optional read-only sleep context, and no social
layer.

Last reconciled with `project.yml`: 2026-08-05.

For current App Store Connect status and submission-ready copy, see
`docs/APP_STORE_SUBMISSION.md`.
For the pending production schema/function change, use
`docs/PLAYBOOKS/production-backend-release.md`.

## Evidence snapshot — 2026-08-01

Locally proven:

- Debug and Release simulator builds succeed.
- A Debug build targeted at the connected physical iPhone succeeds and the current
  development build is installed for NFC end-flow retesting.
- The full unit suite passes; the latest run includes 128 tests.
- A signed Release archive and App Store export succeed for build 10. The exported IPA has
  distribution profiles with `get-task-allow=false` for the app, Watch, report, monitor,
  shield configuration, and shield action targets.
- The exported app carries production Family Controls profiles for the containing app,
  report, monitor, shield configuration, and shield action targets.
- The exported app contains the main and monitor privacy manifests.
- Debug and Release navigation render Home, Nights, Farm, and Settings; internal previews require the
  explicit Debug launch argument.

Read-only external audit:

- App Store Connect version 1.0 is Prepare for Submission.
- TestFlight build 2 is processed and selected for App Store version 1.0.
- Build 10 is prepared locally with preflight start, NFC-authenticated app-access barriers,
  continuous shielding, per-run Live Activity consent, and the qualified six-frame journey.
- App Privacy and the public policy URL are not yet fully reconciled with the new feedback
  disclosures; screenshots, age rating, content rights, remaining legal declarations,
  build-10 upload, and final review submission remain.
- The production Supabase migrations, `live-activity-registration`, `submit-feedback`, and
  `feedback-email-delivery` Edge Functions are deployed and the linked schema is lint-clean.
- Release/TestFlight configuration keeps feedback disabled (`SUPABASE_FEEDBACK_ENABLED=NO`)
  until Resend secrets/domain, the ten-minute Cron, policy publication, mailbox retention
  approval, and physical-device feedback testing pass. The form keeps its recoverable Mail
  fallback.

Not locally provable:

- Real NFC, Family Controls scheduling while terminated, Apple Health stage provenance,
  accessibility on physical devices, full overnight restoration, and App Review acceptance.

## 1. Human account and distribution work

- [ ] Apple Developer Program membership and the Counting Sheep App Store Connect record
      are active.
- [ ] Main bundle ID is `com.ngawangchime.countingsheep`; Team is `4KZQPZR47B`.
- [ ] Register these explicit extension App IDs:
  - `com.ngawangchime.countingsheep.DeviceActivityMonitor`
  - `com.ngawangchime.countingsheep.ShieldConfiguration`
  - `com.ngawangchime.countingsheep.ShieldAction`
- [ ] Assign Family Controls distribution to the main app, Screen Time report, monitor,
      shield configuration, and shield action App IDs. Regenerate distribution profiles
      after approval.
- [ ] HealthKit, NFC Tag Reading, App Groups, Live Activities/push, and Family Controls
      capabilities match the entitlements in `project.yml`.
- [ ] Current artwork is cleared per `ASSET_NOTICE.md`.
- [ ] A public privacy-policy URL reflects `docs/PRIVACY_DATA_MAP.md` and the feedback
      disclosures in `docs/PUBLIC_PRIVACY_POLICY.md`.
- [ ] App Privacy answers disclose any enabled Supabase transport, optional impact data,
      and optional feedback text/email/screenshots/diagnostics.

## 2. Generated project, versions, and archive

- [ ] `project.yml` is the only project source of truth.
- [ ] Increase `CURRENT_PROJECT_VERSION` above the already-uploaded TestFlight build before
      the next upload; confirm `MARKETING_VERSION` is `1.0`.
- [ ] `xcodegen generate` completes.
- [ ] Automatic distribution signing resolves for all eight targets.
- [ ] A Release archive succeeds:

```bash
xcodebuild archive \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoom \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/CountingSheep.xcarchive
```

- [ ] Inspect the archive: all six embedded iOS extensions and the Watch app are present;
      every `.appex` has the expected extension-point identifier and distribution entitlement.
- [ ] Validate/upload the archive through Xcode Organizer or App Store Connect before
      declaring 1.0 ready. Local `altool` validation is blocked until an App Store Connect
      JWT or app-specific password is provided.

## 3. Release scope and product identity

- [ ] Debug and Release expose exactly Home, Nights, Farm, and Settings by default.
- [ ] Farm, Friends, Shop, the legacy shelf, `MVPMockData`, manual analytics, and QA data are
      unreachable without `-ollie.debug.enableMockScreens YES`, and always unreachable in Release.
- [ ] No customer surface calls the ritual a Focus Run or generic productivity session.
- [ ] Current setup exposes App Shielding or NFC + App Shielding. Legacy timer, Watch, and QR
      values remain decodable but are not offered to new configurations.
- [ ] Automatic Wind Down sends 60/30/10-minute lead-ins; with shielding enabled, selected
      apps are limited at the saved start time while the main app is closed.
- [ ] The selected-app barrier continues through Wind Down, sleep, and morning quiet, and
      never prevents opening Counting Sheep.
- [ ] Sleep outcomes are described as context/association, never diagnosis or causation.

## 4. Fresh-install permission sequence

- [ ] Notifications are requested only when saving/starting a requested ritual.
- [ ] Camera denial preserves QR manual fallback.
- [ ] NFC unavailable/cancelled/read-only/full/multiple-tag states preserve honor/QR fallback.
- [ ] Screen Time denial or empty selection preserves an unshielded Wind Down.
- [ ] HealthKit requests read access only to `HKCategoryTypeIdentifierSleepAnalysis`.
- [ ] HealthKit no-data and denied-read ambiguity use honest requested/no-data copy.
- [ ] No permission is requested just by browsing Home or Nights.

## 5. NFC physical-device matrix

- [ ] Register a blank writable NDEF tag, confirm it on the next run, and verify only a
      digest is persisted.
- [ ] Replace the tag; the old tag no longer confirms.
- [ ] From the active NFC recovery state, explicitly pair a replacement tag and
      verify the same Wind Down continues; after a replacement during a running Wind Down,
      only the new tag can authenticate the normal end action.
- [ ] Forget the tag; scanning does not silently re-enrol it.
- [ ] Verify a mismatched tag, repeated scan, cancellation, two tags, read-only tag, and
      insufficient-capacity tag.
- [ ] Confirm the registered tag works offline.
- [ ] Verify scan success followed by Screen Time scheduling failure still starts the local
      ritual and explains the shield fallback.
- [ ] In NFC mode, the normal iPhone end action accepts only the registered tag; a
      mismatched tag or cancelled scan leaves Wind Down and its shields active.
- [ ] The Watch cannot end an NFC-protected Wind Down. The multi-step emergency exit on
      iPhone remains reachable, records the bypass, and clears shields immediately.

## 6. Shielding physical-device matrix

- [ ] Select one disposable test app and one category; never select safety-critical apps.
- [ ] App Shielding applies immediately after an eligible App Shielding start; NFC + App
      Shielding applies only after the registered Wind Down tag is read.
- [ ] The selected-app barrier remains active through wind-down, overnight, and morning
      quiet, and clears at `protectedUntil`, authenticated NFC exit, or emergency exit,
      while Counting Sheep is foregrounded, backgrounded, and terminated.
- [ ] The shield appearance is gentle and “Return to quiet” closes the shielded app.
- [ ] Opening Counting Sheep and ending Wind Down through its configured method—or using
      the emergency exit—immediately clears shields.
- [ ] Reset, replacement run, disabled toggle, no selection, scheduling error, timezone
      change, DST transition, and device reboot do not strand a shield.
- [ ] The completion/history record distinguishes scheduled, partial, unavailable, and
      observed shield evidence; it never assumes scheduled minutes were protected.

## 7. HealthKit and impact measurement

- [ ] Sleep interval and duration match Apple Health for the night-ending date.
- [ ] Core/deep/REM are shown only where present; overlapping Watch/iPhone sources are not
      double-counted, and the chosen source is labelled locally.
- [ ] Two protected plus two other measured nights unlock the local comparison.
- [ ] Comparison copy includes group sizes and says association is not proof of cause.
- [ ] Optional impact consent names every shared category and every important exclusion.
- [ ] Shared records have relative nights only—no exact date/time, source name, selected app,
      NFC identity, raw Health sample, or personal free text.
- [ ] Stop sharing prevents future upload. Delete shared data removes backend rows without
      deleting local detailed history.
- [ ] Hosted migration `20260730090000_optional_impact_data.sql` is deployed and RLS/deletion
      are tested before exposing sharing in production.

## 8. Feedback release gate

- [ ] The form validates 10–4,000 characters, optional email, and zero/one/three screenshots.
- [ ] Each selected image is metadata-stripped JPEG, no more than 2,048 pixels on its longest
      edge and no more than 3 MB; technical details contain only app/build/iOS/device family.
- [ ] Migration `20260801090000_app_feedback.sql` passes SQL tests for table isolation,
      ownership constraints, rate limits, idempotency, and retry state.
- [ ] `submit-feedback` and `feedback-email-delivery` pass Deno checks/tests. The private
      bucket never returns a public attachment URL.
- [ ] Resend sender/domain, recipient, secrets, ten-minute schedule, five-attempt retry, and
      180-day deletion are verified in the production project. The schema and functions are
      deployed, but the production project currently has no `RESEND_*` or feedback-delivery
      secrets and only the existing Live Activity Cron is configured.
- [ ] A physical iPhone submission produces exactly one correctly formatted support email
      with zero/one/three screenshots, including after a simulated first-attempt failure.
- [ ] The support mailbox has an approved process to delete corresponding messages and
      attachments within 180 days.
- [ ] Keep `SUPABASE_FEEDBACK_ENABLED = NO` unless every preceding item passes. With it off,
      the form opens the prefilled Mail fallback and copies the support address when Mail is absent.

## 9. Core lifecycle and restoration

- [ ] Wind-down, overnight, and morning quiet remain phases of one persisted run.
- [ ] Overnight hours never enter quiet-minute totals or change flock value.
- [ ] Background/terminate/relaunch in every phase reconciles correctly.
- [ ] Completion and early end clear Live Activity, notifications, shielding, and placement
      resources without shame or loss language.
- [ ] Watch unreachable/non-UWB always falls back to the timer.
- [ ] Test local midnight, spring/fall DST, timezone change, late start, and app update from
      the current TestFlight build.

## 10. Privacy, accessibility, and review copy

- [ ] Purpose strings describe only actual NFC, camera, Nearby Interaction, and sleep reads.
- [ ] Logs contain no raw tokens, Family Activity tokens, NFC registration token, sleep
      values, or Supabase secrets.
- [ ] VoiceOver and large Dynamic Type can configure, begin, understand, and end the ritual.
- [ ] Night screens are calm; no medical promise, reward tease, guilt, or confirm-shaming.
- [ ] App Review notes explain why Family Controls, NFC, HealthKit, and the three shield
      extensions are needed for a bedtime phone-away ritual.
- [ ] Foqos is referenced conceptually in ADR-0004 only. No NOTICE is required unless source
      is copied later.

## 11. Local merge gate

- [ ] `xcodegen generate`
- [ ] Debug and Release simulator builds succeed.
- [ ] Full unit suite passes on an available iPhone simulator.
- [ ] `git diff --check` is clean.
- [ ] `plutil -lint` passes for every plist and entitlement.
- [ ] `supabase db lint` (or hosted migration validation) passes.
- [ ] Feedback SQL tests and Deno checks/tests pass.
- [ ] Human reviews coordinator, entitlement, target, privacy, and migration changes.

The repository can prove compilation and pure logic. Apple distribution approval,
physical NFC/HealthKit/DeviceActivity behavior, archive upload, and App Store review remain
human/external gates.
