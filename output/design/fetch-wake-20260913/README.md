# Barn crop and wake-before-fetch — 13 September 2026

The original wide Farm backdrop still includes the barn on its right edge. The personal Farm
card now aligns its fill crop to that edge so narrow cards retain the barn. No artwork changed.

Fetch previously selected upright sprites immediately. It now observes the actual rendered
Ollie rest pose, holds position and plays the existing dressed rise sequence before accepting
a throw. Settling, fully resting and already-rising poses are covered. Awake Ollie can start
immediately. Reduce Motion holds rest then switches upright without cycling the rise frames.
Stopping or replacing the scene cancels the wake task as well as an active fetch round.

Validation:
- XcodeGen regenerated membership for the new pure Shared wake sequence.
- Generic iOS Simulator build passed: `build.log`.
- Full iPhone Simulator suite passed: **1,029 tests, zero failures**, `tests.log` and
  `/private/tmp/counting-sheep-fetch-wake-20260913.xcresult`. Three new tests verify the authored
  pose/garment sequence, wake-before-throw gating without movement, and cancellation including
  Reduce Motion.
- `capture-native.py` uses disposable residents and the actual Farm/companion renderer in an
  isolated DEBUG entry. The resting schedule triggers the real pose-reporting path. Captured
  native rest, getting-up, upright/ready, dressed run and return with the barn visible.
- Video frames at 4.4/5.4/5.8 seconds show resting, rising and upright, respectively. Extracted
  frames are direct video samples. Screenshot filenames are requested capture checkpoints;
  actual elapsed capture times are in `capture-times.json`.
- `barn-wake-fetch-preview.mp4` trims startup from the native recording for review.
- `git diff --check` passed. Source hashes accompany the evidence.

This follow-up supersedes the crop and instant rest-to-ready switch in the original fetch
recording. It is local source, not a TestFlight release. No backend changes, commit, push or
upload were performed. Physical gesture feel, device VoiceOver and Reduce Motion acceptance
remain in the existing backlog; Simulator and unit checks do not replace those checks.
