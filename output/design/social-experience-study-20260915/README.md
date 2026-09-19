# Social experience study — captures, 15 September 2026

Native iPhone SE Simulator screenshots of the DEBUG-only prototype under `PhoneInTheOtherRoomApp/Views/Prototypes/SocialExperienceStudy/`. All people, counts and sessions are fixtures. See [HANDOFF.md](HANDOFF.md) for the design rationale, interaction inventory and integration notes.

File names follow `<surface>-<fixture>-<appearance>[-ax5][-bottom].png`. Surfaces: `party` (Slumber Party home), `campfire`, `person` (party member card), `public-person` (public participant card), `home` (entry-card sketch). `-ax5` is Dynamic Type `.accessibility5`; `-bottom` starts scrolled to the lower modules.

| Fixture | Slumber Party | Campfire | Person / Home |
| --- | --- | --- | --- |
| No active sessions | `party-quiet-dark.png`, `party-quiet-dark-bottom.png` | `campfire-quiet-light.png` | — |
| One Wind Down + one Phone Away | `party-twoSessions-light.png`, `-dark`, `-light-ax5`, `-light-bottom`, `-light-ax5-bottom` | `campfire-twoSessions-light.png` | `person-twoSessions-light.png`, `person-twoSessions-dark-ax5.png`, `public-person-twoSessions-light.png`, `home-twoSessions-dark.png` |
| Eight people | `party-eightPeople-light.png` | `campfire-eightPeople-dark.png`, `-light-ax5`, `-dark-bottom` | — |
| Own sharing off | `party-sharingOff-light.png` | `campfire-sharingOff-dark.png`, `-light-bottom` | — |
| Loading | `party-loading-light.png` | `campfire-loading-light.png` | — |
| Failed | `party-failed-dark.png` | `campfire-failed-light.png` | — |
| Stale | `party-stale-light.png` | `campfire-stale-light.png` | `home-stale-light.png` |
| Return / check-in | `party-returnCheckIn-light.png` | — | `person-returnCheckIn-light.png`, `public-person-returnCheckIn-dark.png`, `home-returnCheckIn-light-ax5.png` |

Re-capture: add a DEBUG branch `if ProcessInfo.processInfo.arguments.contains("--social-study") { SocialExperienceStudyNativeFixture() }` to the `WindowGroup` dispatcher in `PhoneInTheOtherRoomApp.swift`, build to `/tmp/counting-sheep-social-study`, then run `python3 capture-native.py` and `python3 capture-native-bottom.py` from the repository root. Remove the branch afterwards; it is not part of the handoff. `#Preview` entry points in `SocialExperienceStudyRoot.swift` need no hook.

`build-final.log` is the generic iOS Simulator build after the capture hook was removed.
