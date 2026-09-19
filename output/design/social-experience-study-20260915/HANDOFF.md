# Social experience study — handback to Astra

Prepared 15 September 2026 by Cursor Fable 5.1 against the [Codex brief](../../../docs/plans/cursor-fable-social-ux-handoff-2026-09-15.md). One initial pass. Everything here is a **DEBUG-only local prototype driven by fixtures**. Nothing is wired into release navigation, no model, service, view-model, routing or shared file was changed, and no backend, package, target, entitlement or signing change was made.

## Recommended direction

**Slumber Party opens a group home, not a Campfire.** The page answers four questions in order: where am I (eyebrow + group name + compact member strip + round line), what is happening now (*Tonight* card), what should I do (one primary button), what is ours (Shared meadow entry, Our next improvement, Recent). *Together now* is the private label for live sessions; the word *Campfire* is reserved for the worldwide place.

Primary action per surface:

| Surface | Primary action | Why |
| --- | --- | --- |
| Slumber Party home | *Start Wind Down*, which becomes *Join with my own Wind Down* when anyone is at the fire; *Back to your session* if I'm running; the three check-in outcomes when I've just returned | The card changes verb with state instead of the screen changing shape. Phone Away is one secondary chip; "Suggest a shared plan" is a text link (proposal). |
| Campfire | *Start Wind Down* / *Start Phone Away* inside a *Sit down* card, always through the **Audience** sheet | Browsing never publishes. Public options stay locked until the separate public agreement is accepted; the sheet previews exactly what a stranger sees. |
| Person / session card | *Join with my own <kind>* while they're active; *Moon glow* acknowledgement afterwards | Encouragement, check-in offer, ask-how-it-went and the proposed connection ladder are secondary and appear only when the audience and session state allow them. |

Structural decisions in the prototype:

- **People button removed.** A compact member strip (avatars + "+N" + chevron) opens a *Members* sheet that is also the accessible list equivalent, with invitations, party sharing, the separate Campfire agreement and notification rows.
- **Live scene is compact and conditional.** `StudyFireScene` (150–210 pt) only appears when fresh sessions exist. An established quiet group lands on identity and the start action, not a blank landscape.
- **Shared meadow is an entry, not the landing.** A 110 pt static glimpse of the real dusk meadow with Shepherds, visiting sheep and the lantern, plus a truthful line ("Saved places, not activity."), *Open meadow* and *Send a sheep / Your sheep*.
- **Send a sheep shows the sheep.** Real catalog art, name, where it is, and *Bring home*. One sheep per party is explained in place.
- **Lantern lives inside *Our next improvement*** with the 12-contribution rule stated in one line.
- **Recent** shows at most two records, with an explicit distinction between "45 before-bed min recorded, rounded" and "before-bed minutes weren't shared" when the value is absent. This is a presentation proposal for the zero-minute confusion; Astra still owns the diagnosis of what the number measures.
- **Public timing is coarse** (`remainingBand`: under half an hour / about an hour / a few hours / through the night); private cards keep exact planned end.
- **Stale is never presence.** `StudyDataState.stale` hides seats and says "Last seen N min ago. Nobody is shown as here now until … refreshes." The same notice component serves loading and failure in both places, with the reassurance that the local timer and Farm are unaffected.

**Rejected alternative:** keeping the segmented *Live sessions / Shared meadow* control on top of a full-height scene and adding a Campfire tab beside it. It keeps two equal-weight views of the same group, still lands on an empty landscape, and gives the worldwide place the same visual weight as a private family. The group-home ordering (identity → now → action → ours) was chosen instead.

## Files

New, all under `#if DEBUG`, none referenced by release code:

| File | Purpose |
| --- | --- |
| `PhoneInTheOtherRoomApp/Views/Prototypes/SocialExperienceStudy/SocialStudyModels.swift` | Fixture models (`StudyPerson`, `StudySession`, `StudyGroup`, `StudyCampfire`, `StudyDataState`, `StudyAudienceChoice`), the semantic `SocialStudyAction` enum with its `integration` note per case, and `SocialStudyActionLog`. |
| `…/SocialStudyFixtures.swift` | `SocialStudyFixture` (8 required states) and deterministic scenario builders. Uses `CountingSheepPublicPresentation.defaultValue` variations and real `SheepCatalog` IDs. |
| `…/SocialStudyComponents.swift` | `StudyEyebrow`, `StudyTruthLine`, `StudyStackOrRow`, `StudyPrimaryButton`, `StudySecondaryButton`, `StudyMemberStrip`, `StudyFireScene`, `StudySessionRow`, `StudyDataStateNotice`, `StudySheepRow`, `StudyActionToast`. |
| `…/SlumberPartyHomeStudyView.swift` | Surface 1. |
| `…/SlumberPartyHomeStudySheets.swift` | Members sheet, Send-a-sheep sheet, proposed Next-night adjustment sheet, and the two Home entry-card sketches (`SlumberPartyHomeEntryCardStudy`, `CampfireHomeEntryCardStudy`). |
| `…/CampfireStudyView.swift` | Surface 2 plus `StudyAudienceReviewSheet`. |
| `…/SocialPersonCardStudyView.swift` | Surface 3. |
| `…/SocialExperienceStudyRoot.swift` | Harness (fixture menu, surface picker, intent toast, in-app interaction inventory), 13 `#Preview`s, and `SocialExperienceStudyNativeFixture` (launch-argument entry). |

`PhoneInTheOtherRoom.xcodeproj/project.pbxproj` was regenerated with `xcodegen generate` (2.45.4) so the new folder is compiled; the diff is only the eight new file references. `project.yml` is unchanged.

Production art and rules reused, read-only: `SlumberPartySocialAvatarView`, `PixelAssetImage` + `SheepCatalog`, `AssetSlot.Farm.sharedMeadowDusk`, `PaperCampfire`, `PaperPastureLantern`, `CampfireRules.fire` / `CampfireRules.seat` (for one or two seats), `CampfireActivity`, `CampfireOutcome`, `PixelCard`, `PixelPrimaryButtonStyle`, `PixelChipButtonStyle`, `PixelSegmentedPicker`, `AppColors`, `AppTypography`, `pixelFont`, `AppSpacing`, `AppRadius`.

## Fixture assumptions

- Names, sessions, counts, gatherings and connections are synthetic. `SocialStudyFixtures.now` is fixed at 15 Sep 2026 14:00 UTC so previews are deterministic; times render in the device time zone.
- Eight seats maximum in `StudyFireScene`; overflow is expressed as "8 of 140 at this fire" plus a *More people* link. Seating uses a two-row local layout for 3–8 people; production can substitute the wide-canvas `CampfireRules.seat` once integrated.
- Gathering titles are strings; a real gathering is server-assigned. "Wind Down" is treated as a gathering alongside Reading/Studying/Making/Resting.
- The party fixture always has a round running (Night 3 of 7) except where noted; `roundNight == nil` renders "No round running".
- `StudyRecord.roundedMinutes == nil` stands for "reached the party without a minute value". Whether production records can carry that state is for Astra to confirm.
- The audience sheet's agreement acceptance is local `@State`; it never persists.
- No Farm/wool/lantern credit is implied for any tap. Fixed encouragement uses the existing cheer vocabulary ("Moon glow") for acknowledgements.

## Interaction inventory

Also readable in-app via Fixture menu → *Interaction inventory*; the source of truth is `SocialStudyAction.integration`.

| Interaction | Status | Connect to |
| --- | --- | --- |
| Start Wind Down / Phone Away with an audience choice | Existing behavior surfaced (audience choice extends it) | Existing start sheets via `FocusRunViewModel`; party choice = `CampfireStartChoices`; public choice is new |
| Review audience | Existing for parties | `CampfireSharingSheet(social:partyID:)`; public agreement is new |
| Accept public sharing agreement | **New proposal** | Public-sharing agreement record, see global Campfire plan consent contract |
| Join another person's activity with my own timer | Existing | `FocusRunViewModel.startNewOneTimeAdditionalQuietNow()` (as `CampfireBuddyCard.onJoin`) |
| Back to running session | Existing | `NotificationCenter` `.countingSheepShowHome` |
| Send fixed encouragement | Existing for parties | `NightFlockViewModel.sendCampfireAction("encourage", …)`; public encouragement is new |
| Offer to check in (volunteer buddy) | Existing, party only | `sendCampfireAction("accept", …)`; one buddy per session |
| Ask how it went | Existing | `sendCampfireAction("checkIn", …)` after `checkInAfter` |
| Acknowledge a returned result | Existing | Fixed cheer on completed record: `sendSlumberPartyCheer` / `cheerMembershipSlumberPartyMember` |
| Share my check-in (Did it / Made progress / Changed plans) | Existing | `sendCampfireAction("reflect", outcome, note)`; first accepted wins |
| Open Members | Existing | `SlumberPartyV4GroupDetailsView` |
| Open Shared meadow | Existing | `SlumberPartyPastureView` in Shared-meadow mode |
| Open Our next improvement | Existing | `SharedPastureLanternSheet(lantern:)` |
| Open a person | Existing for parties | `SlumberPartyMemberUpdatesView` / `CampfireBuddyCard` sheet; public person card is new |
| Send / recall a sheep | Existing | `NightFlockViewModel.contributeSheep(_:partyID:)` / `recallSheep(_:partyID:)` |
| Request / respond to connection | **New proposal** | `campfire-public-command` connect/respond; mutual, 7-day expiry, one open request per pair |
| Invite an accepted connection to a party | **New proposal** | Existing invite disclosure, triggered from a connection |
| Block / report | Existing for parties | `blockSlumberPartyMember` / `reportSlumberPartyMember`; public equivalents are new |
| Retry / refresh | Existing | `refreshSelectedSlumberParty()` / `refreshV4PartyObservation` |
| Change gathering | **New proposal** | Server-assigned topics via `campfire-public-state` |
| Suggest a shared evening plan | **New proposal** | Each adult accepts/edits own participation; no negotiation flow exists |
| Choose a next-round adjustment | **New proposal** | Saves to my own plan only |

## Validation actually performed

- `xcodegen generate` → project regenerated; diff limited to the eight new files.
- `xcodebuild build … -destination 'platform=iOS Simulator,id=60935BFC-…'` (iPhone SE Simulator) → **BUILD SUCCEEDED**, zero warnings from the study files, repeated after each fix.
- Final `xcodebuild build … -destination 'generic/platform=iOS Simulator'` after removing the capture hook → see `build-final.log`.
- Native screenshots on the disposable "Counting Sheep Review iPhone SE" Simulator, light and dark, default and `.accessibility5`, for all eight fixtures across the three surfaces plus Home cards and five bottom-anchored views. Scripts: `capture-native.py`, `capture-native-bottom.py`. Captured with a **temporary** three-line DEBUG branch in `PhoneInTheOtherRoomApp.swift` (`--social-study` → `SocialExperienceStudyNativeFixture()`), which was reverted; the file's SHA-256 matches its pre-edit value. Re-adding that branch is the only step needed to re-run the scripts.
- Visual inspection of the captures drove four repair rounds: removed duplicate inline titles, moved the fixture clock to evening, capped eyebrow Dynamic Type, stacked the audience banner / stale notice / person identity at accessibility sizes, and demoted "Suggest a plan" to a text link.
- Not run: the unit suite. `PhoneInTheOtherRoomTests` compiles `Shared/` + `Tests/` + three listed files only, so the new DEBUG views cannot affect it; no Shared logic was added or changed. No VoiceOver, physical device, network or account behavior is claimed.

## Unresolved decisions for the founder / Astra

1. Whether Home carries **both** a Slumber Party card and a distinct Campfire card (prototype assumes yes, Campfire below the party card).
2. Label for private live sessions: *Together now* is used; *At the fire* appears on the person card title for public sessions only.
3. Should "Suggest a shared plan" appear on the Tonight card at all before the negotiation contract exists, or only inside the round section?
4. Whether the Recent module should display an absent minute value as "weren't shared" (as prototyped) or hide the record until Astra diagnoses zero-minute completions.
5. Public seat cap at one fire (8) versus pagination behavior; gathering list is synthetic.
6. Public encouragement, block/report and the connection ladder all need server contracts before any of the *Proposal* rows become tappable in release.
7. Whether the Campfire page should exist for a signed-out or guest account; the prototype assumes a verified account with a chosen public name.

## Not done, deliberately

No second design direction, no changes to production Home/party routing, no transport, no timer/protection/reward changes, no consent activation, no commit. The founder may request one consolidated revision; after that Astra owns integration and the full acceptance gate.
