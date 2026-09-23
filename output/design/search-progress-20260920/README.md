# Ollie's next search — local implementation evidence

20 September 2026. Implemented and delivered in **TestFlight 1.0 (53)** to Internal QA.
See [release evidence](release-53/README.md); physical acceptance remains separate.

## Result

The existing shared card remains beneath Farm's pasture and on Ollie's Search.
It starts folded with story copy and Ollie's position; its header reveals the
illustration, unspent time/bonus breakdown, rules and independent Phone Away meter.
The pasture, residents/play controls, priority cards, section order and tabs are
unchanged. Existing assets, equipped Ollie accessory and placeholder fallback are reused.

New primary Wind Downs use farm-credit policy 2: a 20-point search bonus for starting
within 15 minutes of planned Wind Down start and reaching intended bedtime, once per
captured night-ending date. Early-ended timer credit stays. Bonus units never grow
wool or change factual minutes. Version-0/1 runs and historical time backfill never
receive a retrospective bonus. The existing terminal transaction delivers the receipt,
searches and arrivals together. No parallel timer, reward service or backend endpoint.

Farm schema 4 protects bonus data from older clients. Lossless schema-3 remote decode
and re-encoding preserve existing queued payload fingerprints until new-policy settlement.
The existing SQL RPC accepts the nested Farm document while retaining outer wire/economy
version 1. No backend source or production deployment was needed for this change;
a live old/new-client account round-trip remains a release acceptance check.

## Native captures

- [Farm context](native-farm.png): production Farm layout with the replacement card.
- [Folded](native-folded.png): compact production component with 81% fixture progress.
- [Expanded](native-expanded.png): production component, separate 61% time and 20% bonus.
- [Large text](native-large-text.png): accessibility3 wrapping and vertical contribution rows.
- [Design concept](folded-expanded-concept.png): reference only, not shipped art.

Captures use isolated Screenbook state on an iPhone 17 Simulator. The screenshot
fixture's sample bonus is never added to a user's Farm. Native review found and fixed
endpoint clipping and prevented decorative art from scaling with Dynamic Type;
readable text continues to scale. Initial review happened while the Mac was locked.
The follow-up live check verified expansion/collapse in Farm and Ollie's Search, scrolling all rules above
the tab bar, and the entire accessibility3 card through its final Phone Away rule.
See [live expanded Farm](live-farm-expanded.png), [live collapsed Farm](live-farm-collapsed.png),
[large-text lower rules](live-large-text-bottom.png), and Ollie's Search
[expanded](live-ollies-search-expanded.png) / [collapsed](live-ollies-search-collapsed.png). The accessibility tree exposes
the disclosure state and separate progress/rule elements and hides decorative art.
macOS VoiceOver was enabled for a navigation attempt, but automation produced no
reliable speech/focus evidence; spoken navigation remains unverified. VoiceOver was
restored to its original off setting afterward.

## Validation

- Generic iOS Simulator build: **passed** (app, Watch and extension dependencies).
- Full iOS unit suite: **1,094 passed, zero failures**.
- Isolated Foundation Farm save/account suite: **80 passed, zero failures**, including
  bonus preservation through account switching and disk reload.
- `git diff --check`: passed.

Commands:

```sh
xcodegen generate
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/counting-sheep-search-build
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=5038FA93-9BED-40C5-838F-D3120B7B9F7F' -derivedDataPath /tmp/counting-sheep-search-build
python3 scripts/validate-farm-save.py
```

The first unit invocation caught a test helper named `run()` colliding with XCTest;
renamed it `makeRun()` and reran successfully. Earlier build/test evidence was replaced
as needed after visual repairs. Save-domain evidence was reused after UI-only edits.
All tests used Simulator or temporary isolated stores, not the founder's account.
See `source-sha256.txt` for the initial implementation snapshot and
`release-53/archive-source-sha256.txt` for the archived source, including the build-number bump.

## Thirty-day deterministic economy comparison

These are illustrative scripted players, not forecasts or proof of real-world habits.
The two policies receive identical run IDs and eligible time; deterministic outcome
seeds can change after an additional search, so extra searches need not always produce
extra sheep in a short sample. Capacity is left at 12 and ready active sheep are sheared.

| Pattern | Searches before → after | Sheep before → after | Pending before → after | Wool before → after |
|---|---:|---:|---:|---:|
| 7-hour bedtime sessions | 30 → 36 | 10 → 10 | 0 → 0 | 123 → 124 |
| Bedtime + 100-minute Phone Away | 60 → 66 | 27 → 27 | 15 → 15 | 193 → 191 |
| Bedtime + 500-minute Phone Away | 180 → 186 | 60 → 66 | 48 → 54 | 341 → 341 |
| 30-minute evening sessions reaching bedtime | 2 → 8 | 2 → 4 | 0 → 0 | 2 → 4 |
| Irregular 4-hour sessions + Phone Away | 47 → 49 | 19 → 22 | 7 → 10 | 118 → 124 |

The bonus adds six searches over 30 qualifying nights. Heavy Phone Away remains the
larger acquisition source. Its daily cap, grouped arrival provenance and recoverable
wandering are separate follow-ups in the scoped plan, not changes hidden in this release.

## Remaining acceptance

- Spoken VoiceOver navigation, smallest supported physical screen and both color schemes.
  Live Farm disclosure/collapse and normal/large-text rule scrolling passed on the QA Simulator.
- Signed-device overnight recovery, Brief Access, account switching, and old/new app
  save compatibility. Simulator math does not prove shielding or phone placement.
- TestFlight 1.0 (53) is processed and assigned to Internal QA; installation and
  physical acceptance remain separate from this distribution evidence.
