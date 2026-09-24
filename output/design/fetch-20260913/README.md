# Personal Farm fetch — 13 September 2026

Implemented in local source: tap a destination or drag/release with predicted flick momentum,
live landing guide, bounded parabolic ball flight and bounce, continuous dressed Ollie run out,
pickup, carry, return and handoff. Only one ball/round can run at once. Nearby sheep anticipate
his route and move at a capped speed, considering other sheep and the Shepherd. Sheep sizing
changes continuously with perspective. Play is presentation-only, without rewards or social writes.

Direction-menu throws provide a non-gesture path. Reduce Motion preserves travel/timing while
removing ball arc/spin and run-frame cycling. Ready-for-another-throw is announced to VoiceOver.
Leaving the visible Farm, backgrounding, changing pasture/membership, or beginning Wind Down
cancels the transient round; Done playing cancels explicitly. The previous ordinary autonomy
scheduler is suspended throughout fetch.

## Validation

- `xcodegen generate` regenerated membership for the new Shared, presentation, fixture and test
  files. Existing uncommitted build number 49 was preserved; no release-number change was made here.
- Full unit gate: `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom
  -destination 'platform=iOS Simulator,id=A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1'
  -derivedDataPath /private/tmp/counting-sheep-shop-build
  -resultBundlePath /private/tmp/counting-sheep-fetch-final-20260913.xcresult`.
  **1,026 tests passed, zero failures** (`tests-final.log`). Eight new tests cover target direction/
  momentum, bounds, landing-before-pickup, continuous phase boundaries and capped run speed,
  Reduce Motion, anticipatory sheep movement, overlapping throw rejection, cancellation and
  replacement-scene isolation.
- Generic Simulator build command is recorded in `build-final.log`.
- `capture-native.py` installed the built app on the isolated iPhone SE Simulator and exercised
  the actual Farm card with DEBUG disposable residents. Inspected ready, aim, outbound,
  carry/handoff, delivered and accessibility-size screenshots. `fetch-round.mp4` records the
  complete round. Filenames indicate capture checkpoints, not authoritative phase timestamps;
  read the on-screen status for the sampled phase.
- Initial checks caught a removed helper still used by a separate shared-meadow study, an
  unsupported preview environment setter and an exact floating-point endpoint assertion.
  The helper was preserved, the setter removed, and interpolation now returns exact endpoints.
- `git diff --check` passed. Current source hashes accompany this record.

## Remaining acceptance

The DEBUG capture starts/aims/releases via production view-model intents. It does not prove
physical drag/flick feel, parent-scroll gesture arbitration, VoiceOver operation, or physical
Reduce Motion behavior. The Mac was locked for native input automation; these device checks
remain in the backlog. No backend change is needed. No archive, TestFlight upload, commit or
push was performed for this fetch change. Existing local campfire repairs remain intact.

Follow-up: [barn framing and wake-before-fetch](../fetch-wake-20260913/README.md) supersedes the backdrop crop and immediate resting-to-ready transition shown in this original recording.
