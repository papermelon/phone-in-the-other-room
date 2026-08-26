# Playbook: App Store 1.0 Readiness

Prepare Counting Sheep 1.0 for TestFlight and App Store review. Product scope is fixed by
`PROJECT_BRIEF.md` and ADR-0003/0004/0006/0007: four Release tabs, one user-facing Wind Down
ritual, optional NFC and continuous shielding, optional read-only sleep context, and only the
feature-flagged invite-only Slumber Party exception defined by ADR-0016.

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
- A signed Release archive and App Store export were previously recorded for build 10. That is
  historical evidence only; build 11 is the locally verified/exported build and the final
  Screen-Free Morning candidate has not been created.
- The exported app carries production Family Controls profiles for the containing app,
  report, monitor, shield configuration, and shield action targets.
- The exported app contains the main and monitor privacy manifests.
- Debug and Release navigation render Home, Nights, Farm, and Settings; internal previews require the
  explicit Debug launch argument.

## Shield Configuration signing/export evidence — 2026-08-23

Locally proven:

- `PhoneInTheOtherRoomShieldConfiguration.entitlements` declares Family Controls and the exact
  App Group `group.com.ngawangchime.countingsheep`; `xcodegen generate` completed and the Release
  simulator build succeeded.
- The development Release archive succeeded for build 11. Deep code-sign verification passed;
  the built Shield Configuration and its embedded Xcode-managed development profile both contain
  Family Controls and the exact App Group.
- The corrected App Store distribution profile `Counting Sheep Main App Store Corrected` has
  application identifier `4KZQPZR47B.com.ngawangchime.countingsheep`, `get-task-allow=false`, and
  the required main-app capabilities. The seven valid target App Store profiles were installed and
  checked for their target bundle identifiers and distribution state.
- Manual `app-store-connect` export of build 11 succeeded. The IPA is
  `/tmp/counting-sheep-shield-app-group.fMCmji/Export7/Counting Sheep.ipa`; its Shield
  Configuration codesign entitlements and embedded distribution profile both contain Family
  Controls, `get-task-allow=false`, and `group.com.ngawangchime.countingsheep`. Deep codesign
  verification passed for the exported app.

Still open:

- Physical four-presentation Shield Configuration QA remains incomplete.

Read-only external audit:

- App Store Connect version 1.0 is Prepare for Submission.
- TestFlight build 2 is processed and selected for App Store version 1.0.
- Build 11 is verified/exported locally but not claimed uploaded or processed. The final
  Screen-Free Morning candidate still needs creation after the physical gates below.
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
- [x] Assign Family Controls distribution to the main app, Screen Time report, monitor,
      shield configuration, and shield action App IDs; seven valid App Store profiles were
      installed and verified on 2026-08-23.
- [x] Assign App Groups to the Shield Configuration App ID and regenerate its distribution
      profile; verified in `Counting Sheep Shield Configuration App Store` on 2026-08-23.
- [ ] HealthKit, NFC Tag Reading, App Groups, Live Activities/push, and Family Controls
      capabilities match the entitlements in `project.yml`.
- [ ] Sign in with Apple is enabled for the main App ID and its regenerated development and
      distribution profiles contain `com.apple.developer.applesignin` before Slumber Party is enabled.
- [ ] Current artwork is cleared per `ASSET_NOTICE.md`.
- [ ] A public privacy-policy URL reflects `docs/PRIVACY_DATA_MAP.md` and the feedback
      disclosures in `docs/PUBLIC_PRIVACY_POLICY.md`.
- [ ] App Privacy answers disclose any enabled Supabase transport, optional impact data,
      optional feedback text/email/screenshots/diagnostics, and any enabled Slumber Party account,
      positive check-in, reaction, block, and report data.

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
- [x] Re-run App Store export after the regenerated Shield Configuration distribution profile is
      available; manual App Store Connect export and embedded-profile/effective-entitlement
      inspection passed for build 11 at `/tmp/counting-sheep-shield-app-group.fMCmji/Export7`.

## 3. Release scope and product identity

- [ ] Debug and Release expose exactly Home, Nights, Farm, and Settings by default.
- [ ] Legacy Friends/Farm/Shop, the legacy shelf, `MVPMockData`, manual analytics, and QA data are
      unreachable without `-ollie.debug.enableMockScreens YES`, and always unreachable in Release.
      The production Farm/Shop remain real-data surfaces; Slumber Party is present in
      TestFlight/Release when `SUPABASE_NIGHT_FLOCK_ENABLED=YES`, and hidden in ordinary Debug.
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
- [ ] Legacy QR and Honor Timer values remain decode-only and are absent from release setup.
- [ ] NFC unavailable/cancelled/read-only/full/multiple-tag states leave the requested start
      uncommitted and preserve the app-protection repair path.
- [ ] Screen Time denial, revocation, unavailability, or empty selection blocks every new Wind
      Down, Screen-Free Morning, and Phone Away start and routes to repair; runtime failures
      after a valid start fail open without false shield evidence.
- [ ] HealthKit requests read access only to `HKCategoryTypeIdentifierSleepAnalysis`.
- [ ] HealthKit no-data and denied-read ambiguity use honest requested/no-data copy.
- [ ] No permission is requested just by browsing Home or Nights.

## 5. NFC physical-device matrix

- [ ] With two blank writable NDEF tags, pair a named primary and named backup. Confirm the UUID
      credential is present only in each physical NDEF payload; defaults, logs, and network traffic
      contain no raw credential; defaults retain only its digest and local name/purpose/timestamps;
      names, purposes, and place details are never written to NFC or transmitted.
- [ ] Assign one tag to both Wind Down and Phone Away and prove it starts/ends each mode. Assign
      the other to one mode and prove a wrong-purpose scan leaves the other mode active.
- [ ] Attempt to pair the same physical Counting Sheep tag into both slots. The app must identify
      its existing local name, avoid overwriting it, and direct the tester to Rename or Change uses.
- [ ] Use Test on primary, backup, wrong-purpose, and unknown tags. A recognized scan reports its
      local name and uses and updates only `lastVerifiedAt`; no run, reward, shield, schedule, or
      history outcome changes. An unknown tag is never enrolled silently.
- [ ] Replace each slot; the old tag no longer confirms that slot and the replacement keeps the
      slot's stable local identity, edited name, and uses.
- [ ] After replacing a slot, scan the retired old tag during replacement and Test. It must show a
      clear previously paired/resync-from-Settings failure, never a success check, and must leave
      the current registration unchanged.
- [ ] Settings-only retired-tag resync — primary slot: select the primary slot, scan only its
      locally retired physical tag, and confirm a fresh credential is written before the primary
      registration changes. The old credential remains rejected by Test/start/end; the fresh
      credential works, while the stable local ID, name, and purposes remain intact. Record dated,
      redacted physical-device evidence; this is a human-authorized device gate, not TestFlight
      upload evidence.
- [ ] Settings-only retired-tag resync — backup slot: repeat the same check with the backup slot
      selected. Confirm neither slot is changed by cancel, unreadable read, multi-record message,
      unknown occupied data, query failure, or write failure; each old credential remains rejected
      and the still-active credentials continue to work. Record only slot labels and a redacted
      screenshot/log reference, never NFC credentials or digests.
- [ ] From the active NFC recovery state, explicitly pair a replacement tag and
      verify the same Wind Down continues; after a replacement during a running Wind Down,
      the run and shield stay active throughout and only the replacement can authenticate the
      normal end action.
- [ ] Complete Lost this tag? for primary and backup without the old tag. Cancel once before the
      write and force one write failure; the old registration must remain. After success, only
      the replacement credential occupies that slot.
- [ ] Forget primary with and without a backup, then forget backup; scanning does not silently
      re-enrol either physical tag and a remaining backup normalizes safely to primary.
- [ ] Verify a mismatched tag, repeated scan, cancellation, two tags, read-only tag, and
      insufficient-capacity tag. Every failure preserves the old slot and any active run/shield.
- [ ] Confirm pairing management, Test, NFC start, and authenticated end work offline.
- [ ] Verify scan success followed by Screen Time scheduling failure still starts the local
      ritual and explains the shield fallback.
- [ ] In NFC mode, the normal iPhone end action accepts only a registered tag assigned to the
      active mode; mismatch, wrong purpose, cancellation, unavailability, or missing local
      registration leaves Wind Down/Phone Away and shields active.
- [ ] The Watch cannot end NFC-protected Wind Down or Phone Away. The deliberately multi-step
      iPhone emergency exit remains reachable during replacement, records `emergencyBypass`,
      and clears current shields plus stale automatic schedules immediately. Authenticated exits
      record `nfcTagAuthenticated` and perform the same safe cleanup.
- [ ] For both NFC Wind Down and NFC Phone Away, verify the always-visible primary “Tap tag to
      end …” action; wrong-purpose, cancelled, and unavailable scans leave the run and barrier
      intact. Expand “Can’t use your tag?”, use the one lost/replacement route, then verify the
      emergency sheet uses the two-step local reason reflection: enter a non-empty reason, then
      retype it with trim/case/smart-apostrophe normalization; empty input, mismatch, dismiss,
      replay, and a stale run
      leave the run active; a confirmed exit immediately clears shield, notifications, usage
      monitoring, Live Activity, and any automatic schedule. Repeat while offline and during an
      active shield replacement. Check VoiceOver labels, dictation, and large Dynamic Type; prove
      the Watch cannot invoke the emergency path. In Debug, confirm the support details identify
      Ordinary Debug versus Slumber Party QA with version/build and feature status; verify no
      development-build row appears in a Release archive.

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

## 9A. Slumber Party release gate

- [x] Historical migrations, the invite-recovery migration, and
      `20260825110000_night_flock_parties_v4.sql` are reviewed and applied before deploying the
      matching authenticated Edge Functions. On 2026-08-25 the production database was confirmed
      current and both functions were ACTIVE with JWT verification enabled.
- [x] Before deploying the matching command function, the hosted Edge secret
      `NIGHT_FLOCK_INVITE_KEY_V1` contains 32 cryptographically random base64-encoded bytes.
      `NIGHT_FLOCK_INVITE_KEY_VERSION` selects a provisioned version, and older versioned keys
      remain available until every invitation using them has expired, been revoked, or been
      replaced. Both production secret names were confirmed without exposing values.
- [ ] Verify hosted invitation creation/recovery, Apple-link/manual-link recovery, the approved
      retention schedule, and legacy v1–v3/v4 compatibility without exposing secret material.
- [ ] Direct protected-table writes remain unavailable; outsider, former-member, invite,
      cross-party, five-party-cap, and account-grant SQL/RLS tests pass against the release schema.
- [ ] A moderation owner can inspect fixed-enum reports and apply service-only actions; deletion
      and incident procedures are documented before inviting testers.
- [ ] Physical Apple-linked accounts prove ownership-preserving linking; named groups and repeatable
      seven-night rounds; member-shareable/host-managed active invites; late joining/backfill;
      five-party membership; curated profile/name-limit synchronization; rounded Wind Down/Phone
      Away records, expiring statuses, silent fixed cheers, offline retry, per-party rewards,
      member leave, host deletion, and full account deletion.
- [ ] During active Wind Down there is no Slumber Party UI, reaction surface, social navigation, or
      audible alert. A bounded subscription may update only the existing Live Activity/Watch system
      surfaces; backend failure never delays or changes the local run/reward/Farm result.
- [ ] The public policy and App Store review notes match the enabled behavior. Release compiles
      with `SUPABASE_NIGHT_FLOCK_ENABLED=YES`. Hosted backend, Apple provider, moderation, and
      two-account physical evidence still need to be current before inviting testers.

## 10. Privacy, accessibility, and review copy

### Authentication recovery evidence — human/hosted/device gate

Do not record Apple, Supabase, or invite identifiers. For each row use a date, build, redacted
device/account label, lane, outcome, and redacted screenshot/log reference only.

| Date | Controlled case / lane | Expected evidence | Actual / redacted reference |
| --- | --- | --- | --- |
|  | 401: v1/v2/v3 state, direct command, and outbox | Same Apple account reconnects; snapshot, run contexts, and all outboxes remain until reconciliation/flush. |  |
|  | linked_account_required: v1/v2/v3 state, direct command, and outbox | Only the active anonymous session can link in place; its Supabase UUID is unchanged. |  |
|  | wrong/new Apple account | Fail closed; local state remains and no foreign snapshot is displayed. |  |
|  | cancellation/offline | Pending recovery and all local state remain; no anonymous account is created. |  |

Pending explicit human approval, the proposed NFC usage description is: “Counting Sheep reads the
NFC tags you pair to start and end Wind Down and Phone Away.” Do not add it to the target until approved.

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
- [ ] Feedback and Slumber Party SQL tests and all Deno checks/tests pass.
- [ ] Human reviews coordinator, entitlement, target, privacy, and migration changes.

The repository can prove compilation and pure logic. Apple distribution approval,
physical NFC/HealthKit/DeviceActivity behavior, archive upload, and App Store review remain
human/external gates.
