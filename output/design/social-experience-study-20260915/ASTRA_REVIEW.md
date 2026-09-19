# Astra review of the social experience study

Reviewed 16 September 2026. Scope: Fable's delivered source, handoff, build log and representative native screenshots. This is a design/integration review; no production view, session logic, public service or sharing agreement was changed by this review.

**Recommendation, revised after founder feedback on 16 September:** retain the useful hierarchy and finish the remaining work in Astra, using one **Campfire** experience with **Off / My Slumber Party / Global** visibility. The proposed “Together now” name and public-only Campfire identity are superseded by the [current visibility plan](../../../docs/plans/global-campfire-2026-09-15.md). Another broad Cursor pass is unnecessary. Public implementation remains future work. The study is useful design evidence, not a drop-in production feature; its screenshots/source retain the earlier naming as review evidence.

## What to retain

- Preserve group identity and distinguish the live Campfire, persistent Shared meadow, and group project. Campfire uses the same name across private and global audiences.
- A member strip opens the accessible Members destination with invitations and settings. Remove the redundant People toggle; keep list access to everyone, including people outside the illustration.
- Put Send a sheep beside the meadow, with sheep artwork, visiting state and recall. Put lantern progress within the shared improvement rather than giving three unrelated actions equal weight.
- Use a compact current-session illustration and useful quiet/loading/error states. A large empty meadow should not dominate a group's landing screen.
- Reuse the person-card layout, with different private/public data and actions. Preserve separate Wind Down and Phone Away sessions in both the scene and the list.

## Corrections required during production integration

These are integration blockers and prototype limitations, not claims that the DEBUG study has changed shipped behavior.

### 1. Preserve session kind through every start and join

`SocialPersonCardStudyView.swift:144` labels the action with the selected person's session kind, but `SocialStudyModels.swift:227` maps every join to `startNewOneTimeAdditionalQuietNow()`. That existing method prepares **Phone Away**, so connecting the mapping literally would make “Join with my own Wind Down” prepare the wrong mode. Route the typed intent through the appropriate existing start flow, then its protection/readiness and audience confirmation. Joining never adopts another person's timer or bypasses the local coordinator.

The group primary action also always says Wind Down, even when the only other session is Phone Away. Use the personal routine phase and explicit mode choice; daytime Phone Away must not read as a compulsory bedtime action. Preserve the existing Home start hero. “The Home cards do not start sessions” applies to the two social entry cards, not all of Home.

### 2. Make audience status describe actual consent and delivery

The study's single `partySharingOn` Boolean cannot represent the existing party agreement, separate live-session agreement, selected parties, or publication result. Group copy promises sharing with one named group while sending `.myParties` (`SlumberPartyHomeStudyView.swift:99`). Carry selected party IDs and accepted receipts explicitly; agreement acceptance and confirmed session visibility are different states.

The public banner is based on agreement acceptance alone, and “Review audience” opens a Wind Down start sheet (`CampfireStudyView.swift:80–86`). Give agreement review its own destination. Show whether this session is private, shared with selected parties, public, pending confirmation, or no longer shared. Do not infer “nothing about you was sent” from a failed discovery read (`SlumberPartyHomeStudySheets.swift:218`); an earlier publication may still exist.

Keep public consent independent. The local name/activity/acceptance controls need a typed, versioned submission contract before integration; the current action log is not that contract. The public preview must show the chosen name, Shepherd, mode, preset activity and coarse timing, rather than promise that only a first name and duration are exposed. Public disclosure must not inherit private intentions, party names or history.

### 3. Preserve morning eligibility and freshness

The study offers “Ask how it went” after a session becomes inactive, and offers an own check-in when `ended` is true (`SocialPersonCardStudyView.swift:164` and `:35`). Its model lacks `checkInAfter`. Production `CampfireBuddySession.mayReflect(at:)` deliberately waits for the Wind Down morning-quiet boundary. Derive eligibility from that rule and the accepted server state; do not let a finished overnight timer trigger an early morning prompt. Derive the requester name as well—the group's check-in prompt currently hardcodes Papa.

Public `seated` currently checks only the snapshot state, not session expiry/end (`CampfireStudyView.swift:26`), and person cards find the first session by person ID across private and public arrays. Integration needs a scoped session identity, audience and observation state. Expired or stale sessions must not regain live actions by opening a person card. Switching gatherings must load the selected gathering's participants, not only change its title/count.

### 4. Keep recorded zero, missing data and metric kind distinct

`StudyRecord.roundedMinutes` is optional, but current `NightFlockV4Activity` and `NightFlockV4SharedActivity` require an integer. The nil fixture is not evidence that the build-51 zeros were missing values. Trace the actual before-bed record before changing that meaning. Keep valid zero-valued records available; use a neutral summary and put the factual metric in detail instead of making zero the headline.

`recordDetail` currently labels every mode as before-bed minutes (`SlumberPartyHomeStudyView.swift:294`). Reuse the production mode-aware presentation for Wind Down versus Phone Away. Likewise, a mixed-session Home summary must not give everyone the first person's mode/end time. A clearer summary is “2 sharing · 1 Wind Down · 1 Phone Away.”

### 5. Finish the hierarchy and accessibility pass

The Campfire start action follows the entire participant list (`CampfireStudyView.swift:44`); the eight-person capture requires substantial scrolling to reach it. Move a concise start/return action near the top, followed by audience status and the gathering. Keep the first overview to a few people, with a deliberate path to the full list. Large-text layout should flow and scroll without obstructive pinned controls.

The AX5 party captures avoid the original broken button words, but the long round/sharing line and introductory prose still consume most of the first screen. Reduce duplication, shorten the status and surface the next action earlier. Keep Dynamic Type support; do not solve density by shrinking or capping essential text. Full disclosure stays available in its dedicated sheet. Replace implementation language such as “completed round grant” with ordinary project-progress copy.

The public start currently passes `hasParties: true` and obtains the current person from `scenario.group`. Add a real zero-party account state before calling Campfire independent. Existing screenshots also do not establish VoiceOver operation or the layout with the production tab bar and running-session return bar.

## Recommended answers to the handoff's open choices

These are implementation recommendations, not a record of new founder approval for public activation.

| Choice | Recommendation |
| --- | --- |
| Home entries | Keep direct access to the group and Campfire within the existing four tabs, preserving the personal ritual hero. Two equally prominent cards are not required. Private-group and independent Campfire entries use the same audience-aware experience. |
| Naming | Slumber Party = private group; Shared meadow = its persistent shared place; Campfire = live shared sessions with Off / My Slumber Party / Global visibility. Remove “Together now” from the production recommendation. |
| Primary labels | Prefer explicit Start Wind Down / Start Phone Away, or Back to your session. Do not use “tonight” for every daytime activity. |
| Zero-minute records | Preserve truthful records and mode-specific detail. Never turn zero into unknown. Simplify the Home summary. |
| Shared-plan proposal | Keep it out of the first production integration until its acceptance/negotiation behavior exists. Existing buddy support and sheep/project interactions already give the private group useful actions. |
| Public capacity | Retain the proposed maximum eight illustrated seats, with a bounded paginated list beyond them. Treat a fire's visible-seat count separately from approximate worldwide/topic totals. Validate server assignment and load before choosing rollout capacity. |
| Public connections | Follow working public presence and moderation. Mutual request/accept/decline is a separate delivery slice; do not wire private party IDs into public actions. |
| Guest behavior | First public implementation: an authenticated account can browse with zero parties and without publishing. Publishing requires the independent public agreement. Defer signed-out participant browsing until its access/abuse contract is settled. |

## Astra implementation sequence

1. **Private social integration.** Build the real group home, Members destination, mixed-session Campfire, meadow/sheep/project hierarchy and shorter copy using existing services. Correct start routing, consent status and check-in eligibility together. Put required agreements inside the visible audience-choice flow. Keep global capability unavailable until implemented; retain the Campfire name for both audiences.
2. **Wind Down → Screen-Free Morning → return.** Apply the visual patterns to the existing coordinator's phases: evening readiness/start, clear overnight and morning state, return receipt, optional reflection and a next-evening adjustment. Do not add a second session state machine or convert timer evidence into claims of sleep/task completion.
3. **Public presence implementation.** Finalize independent audience/profile/receipt contracts, account isolation, server-observed expiry, bounded gatherings, withdrawal, block/report and moderation. Then connect the Campfire view and public Home entry. See the [global plan](../../../docs/plans/global-campfire-2026-09-15.md).
4. **Mutual connections.** Add requests and explicit party invitations after public presence works. WebRTC is unnecessary for these presence, timer and fixed-interaction flows; audio/video would be a separate feature decision.

For code integration, run the repository's full app build and unit gate, plus meaningful tests for typed start routing, consent/audience projection, mixed modes, expiry and morning eligibility. Inspect small-phone light/dark and largest text in the real shell, then VoiceOver. The original two-account build-51 report still requires fresh consented Wind Down and Phone Away sessions on physical phones after an updated build is distributed; neither synthetic seats nor a successful build proves that result.

## Evidence and limits

- Delivered source contains **eight** DEBUG-only Swift files; the pasted summary says seven. [HANDOFF.md](HANDOFF.md) lists the actual file set and detailed behavior. Its implementation uses explicit Start Wind Down / Start Phone Away buttons; the pasted summary's exact CTA labels are not the current source.
- Confirmed `** BUILD SUCCEEDED **` in Fable's [final log](build-final.log). Confirmed no `--social-study` / `SocialExperienceStudyNativeFixture` reference remains in the app entry file. The original pre-edit hash is not independently available to this review; the restoration hash comparison is Fable's recorded evidence.
- Inspected the normal party, Home cards, busy public Campfire, AX5 party top/bottom, busy public bottom and return-person captures. The capture folder contains 31 PNGs; see the [capture index](README.md). This is representative inspection, not a claim that every interactive path or every capture was re-tested.
- Independently ran `git diff --check`; no whitespace errors. No app build, unit suite, live-account/network interaction, physical-device check or VoiceOver session was run during this documentation-only review.
- No production integration, public activation, deployment, distribution or commit was performed by this review. Existing unrelated working-tree changes remain intact.
