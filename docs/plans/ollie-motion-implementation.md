# Ollie motion: production asset and runtime pass

2026-08-28. **Source and assets accepted after independent review. Not release acceptance.**

## Scope and authorization

The founder explicitly approved local image processing to remove generated backgrounds,
register frames and align cosmetics. This pass finishes the previously incomplete Home/Farm
animation slice. The native Home remains Ollie alone; window, social layout, session start,
protection, reward and account behavior are preserved.

The working candidate remains `codex/night-flock-mvp` at HEAD
`cce766d1840a850a23d5c47e4a542203c26a728b`, with inherited uncommitted work.
Before-edit source copies and hashes are in `/tmp/counting-sheep-ollie-motion-20260828/`.
They distinguish this pass from the earlier Home and membership-sharing repairs.

## Asset contract

- Preserve the existing neutral Ollie at the beginning/end of actions.
- True RGBA sprites share a 512-pixel canvas and the existing paw baseline.
- Retain the existing head tilt; add the approved photo-based ear tuck, brief tongue greeting,
  and tuck/flop/rest/rise sequence. Rest lasts several seconds; neutral pauses separate actions.
- The three finished accessories receive pose-aligned layers. Unavailable future cosmetic
  artwork retains a truthful fallback; it must not float over a moving body.
- Preserve original source images and record deterministic processing parameters/provenance.

## Runtime contract

One pure action/frame vocabulary drives Home and the selected Farm pasture. Animation state
is local to its view and does not publish session, social or reward changes. Wake only at
authored frame boundaries. Offscreen/background/Reduce Motion stops motion, and re-entry
starts from neutral rather than an arbitrary wall-clock pose. Farm drag and hit targets remain
unchanged; Shop and social thumbnails stay still.

## Implemented

- 64 new imagesets: ten registered base poses, 36 action cosmetic layers, and 18 original
  head-tilt cosmetic layers. The two neutral endpoints reuse the original Ollie image.
- Local Apple Vision foreground segmentation removes the painted checkerboard. Source-crop
  hashes key the preserved masks; deterministic Pillow processing registers and composites
  the accepted layers. No new image service or dependency was added to the app.
- The original build-36 production cycle was 90.39 seconds with an 11-second first greeting.
  Build 37 shortens the neutral holds to a 39.39-second cycle and starts the head tilt after
  one second. The five-second rest is contiguous with settling/rising. The local monotonic clock wakes at authored
  boundaries; it does not publish app/session state or use a display-frame timer.
- The three finished accessories retain opaque fabric/bell below the jaw, with pose-specific
  occlusion behind the head and paws while lying. Missing action assets hold neutral; the
  entire settle/rest/rise group is checked together, including equipped layers.
- Home's prior preference-based geometry bridge never supplied its art frame. Diagnostics
  showed a valid viewport but a permanently null art frame. Direct geometry observation fixed
  visible Home playback without disabling offscreen pausing. Temporary logs were removed.
- Farm's eager scroll content now reports viewport/pasture geometry directly too. Only the
  new companion motion uses this added visibility gate; existing interactions and scene
  controller behavior are unchanged. The visible pasture was recaptured after this addition.
- A DEBUG-only Screenbook flag provides a 13.39-second review cycle with short neutral holds;
  action durations and five-second rest stay unchanged. Cosmetic overrides never persist and
  require an existing Screenbook launch. Ordinary Debug/Release use the production cadence.

### Build 37 production-cadence check — 28 August

The user reported that Ollie looked static on their phone. No new missing asset or viewport
wiring regression was found against the build-36 snapshot. Its long neutral holds made short
Home visits likely to miss the gestures. The simulator also had Reduce Motion enabled by the
Screenbook script; this is not evidence of the phone's accessibility setting or a proven cause
of the physical-phone report. Reduce Motion remains respected.

Parent recorded 58 seconds of the actual Home scene with normal production cadence (without
the accelerated review flag), then inspected filmstrips showing head tilt, ear tuck, tongue,
resting and rising with the equipped bandana. Evidence is under
`/tmp/counting-sheep-home-restoration-20260828-204351/`: `home-production-motion.mov`,
`home-motion-hero-contact.jpg`, `head-tilt-detail.jpg`, and `ear-tongue-detail.jpg`.
The simulator's original Reduce Motion and text-size settings were restored after checks.
This is not physical-device performance evidence; new production-speed Farm recording and
physical scroll/drag checks remain open. Earlier Home/Farm accessory recordings below used
the faster review cadence.

## Corrections before acceptance

The first color matte damaged white fur and left sticker-like borders; it was rejected.
Subsequent checks corrected tail/crown clipping, a white-neck mask hole, a visible graft seam,
and cosmetic placement/occlusion. Parent builds also caught and corrected two Swift errors
in early runtime work. These failures are not green validation. Native recordings exposed the
Home visibility failure even after the unit suite passed. A final duration audit corrected the
schedule's 1.18-second settle to the actual 1.22 seconds and added a consistency regression test.

## Parent verification

Paths below are relative to `/tmp/counting-sheep-ollie-motion-20260828/`.

| Check | Actual evidence |
| --- | --- |
| Asset reproduction | Independent `scripts/art/build_ollie_motion.py --publish` reproduced all 128 catalog file hashes exactly. |
| Runtime/asset contract | `parent-art-verification.json`: 67 required assets resolve as non-empty 512×512 RGBA; action poses/durations match the art manifest. All 64 new PNGs checked. |
| Provenance | All 162 recorded input/output/catalog hashes matched. New source PNGs total 2,679,794 bytes; this is not a decoded-memory or installed-size benchmark. |
| Alpha and composition | Parent inspected base and accessory contact sheets on dark/grass backgrounds and the full multi-background sheet. QA reports zero nontransparent canvas-edge pixels. |
| Generic simulator build | `build-r8-final.log`: **BUILD SUCCEEDED** after diagnostic removal and all assets installed. |
| Main tests | `test-r8-final.log`, `tests-r8-final.xcresult`: **721 tests, zero failures; TEST SUCCEEDED**, iPhone 17e. |
| Recovery | `recovery-r8.json`: **15 cases, all passed**. No recovery/session code changed in this slice. |
| Actual Home/Farm recordings | `native-r8/`: eight ~16-second clips (bare plus all three accessories in each scene), screenshots, filmstrips and `captures.json`. Parent checked grounding, gestures, rest/rise and accessory continuity. Review cadence, not a production-speed performance benchmark. |
| Reduce Motion | `native-r8/*-reduce-motion.mp4`: both scenes held the original neutral pose for ~15 seconds with moss equipped. Simulator preference was restored to its original `0`. Compression causes minor pixel differences; no pose motion was observed. |
| Native interaction | `native-r8/interactions.mp4`: Home→Farm, Ollie double-tap→Ollie Shop, return to Home, background via system Home and foreground via app icon succeeded. |
| Final Farm visibility addition | `build-r9-final.log`: **BUILD SUCCEEDED**. `test-r9-final.log`, `tests-r9-final.xcresult`: **721 tests, zero failures; TEST SUCCEEDED**. `native-r9/farm-moss.mp4` and filmstrip confirm visible playback and unchanged composition after the scroll gate. |
| Real equipment binding | With no motion-review or cosmetic override flags, Shop's Take off and Wear actions both updated Home on tab return without restart/backgrounding. `native-r9/equipment-home-off.jpeg` and `equipment-home-on.jpeg`; fixture's original moss accessory restored, wool unchanged. |

## Independent final review

The configured Sol High reviewer returned **ship for scoped source/assets**, with no blocking
defect. It inspected source against this pass's captured baseline, matched all 162 provenance
hashes, checked base/cosmetic sheets and native filmstrips, and read the actual final validation
artifacts. It did not rerun builds or publish assets; the independent reruns above were the
parent's work.

The reviewer was instructed to remain read-only. The host's effective filesystem permission
was unrestricted, so this was not an enforced read-only sandbox. Parent comparison of all
5,614 guarded repository/proof files found **zero changed, missing or new files** during review.
Evidence: `/tmp/ollie-motion-review-before.json` and
`/tmp/ollie-motion-review-state-audit.json`. Later equipment screenshots and this documentation
update were made after that audit.

Follow-ups: **P2** manual viewport exit/re-entry, drag pausing and lowest-control reachability;
**P3** extend incomplete-rest regression coverage to remove an equipped overlay for each of the
three supported accessories (the existing test removes base frames). Neither is represented
as completed validation. Physical performance and accessibility acceptance also remain open.

Changes remain uncommitted alongside the inherited candidate work; no mixed-scope commit,
push, backend deployment or distribution was performed.

## Remaining gates and limitations

- Scroll and long-press-drag automation did not produce reliable gestures. It did not establish
  viewport-exit/re-entry or drag-pause acceptance. This is not proof that scrolling is broken;
  recheck manually, including reaching the lowest Home/Farm controls.
- Physical-device frame pacing, memory/energy behavior, long residence and interruption during
  every pose remain unmeasured. No simulator frame count or build is a substitute.
- Small-device/Dynamic Type/VoiceOver and the earlier Purpose-fixture integration gaps remain.
  Physical protection/overnight, two-account social, Apple recovery, privacy/retention and
  hosted rollout gates remain separate. No backend, signed archive, TestFlight or phone update
  was performed here.
- The existing Shop/social thumbnail treatment was preserved. Future accessory artwork is not
  invented by the motion renderer; its existing fallback remains in place.

## Reproduce art

Use the bundled Python with Pillow/numpy, or an equivalent environment:

```sh
python3 scripts/art/build_ollie_motion.py --publish
```

Default invocation writes QA artifacts only. `--publish` updates only the new `dog_ollie_*`
catalog set. Preserved source images, keyed Vision masks, manifest, QA sheets and hashes live
in `output/design/ollie-motion-20260828/`. Original neutral/head-tilt/cosmetic sources remain
unchanged. New Vision segmentation requires a compatible local macOS SDK; reproducing the
accepted source crops uses the retained masks.
