# Counting Sheep — Progressive Onboarding and Small-iPhone Optimisation Plan

**Status:** Founder-directed implementation plan, 2026-08-24  
**Handoff target:** Luna High  
**Scope:** first-run guide, onboarding gift presentation, and responsive layout on first-run-reachable iPhone screens  
**Out of scope:** tabs, targets, entitlements, `project.yml`, backend behavior, reward balance, or a new persistence framework

> **2026-08-26 founder amendment:** The subsequent first-run decision supersedes the former
> two-question, combined-result, profile-matched-gift amendment. Six categorical local questions
> form one skippable chapter; a separate explanation uses only explicit behavioral evidence.
> Every person may independently choose one immediately claimed Shepherd welcome gift, including
> after skipping the questions. Schedule/reminder choices remain explicit and automatic start
> remains off. The chaptered post-setup guide decisions below remain current; older
> profile-dependent gift wording in the historical plan is superseded.

## Outcome

Replace the current 17-step uninterrupted tour with short, opt-in chapters that teach no more
than four things at once, then return control to the player. Repair the iPhone 12 layout failures,
make Resume produce an immediate visible result, and introduce the Moonlit Coat once with an
actual preview and an explicit wear-or-keep choice.

The finished experience should feel like this:

1. Setup ends and offers **4 Home basics**.
2. The player completes or skips those four tips.
3. The overlay goes away and the player explores normally.
4. Farm, Nights, Settings, practice, and Slumber Party guidance appears only when the player
   reaches or requests the relevant feature.
5. No tutorial navigation silently claims, equips, shears, purchases, or otherwise changes Farm
   state.

## Evidence and diagnosed causes

The supplied iPhone 12 screenshots are evidence only. They show:

| Evidence | User-visible problem | Code-level cause |
|---|---|---|
| IMG_8260–8263 | The coach card hides most of the highlighted screen. | `CountingSheepOrientationTourOverlay` measures a content-driven card with no height budget, then places the whole card above or below the target. Long copy and the global header make the card dominant. |
| IMG_8261–8264 | “Continue” wraps into a narrow vertical column; Skip and Back also become oversized. | Three controls share one `HStack`; the primary button has large horizontal padding but no minimum readable width or adaptive stack fallback. |
| IMG_8260–8264 | “1 OF 17” makes every lesson look like one compulsory marathon. | `FirstRunJourney.number/count` derives progress from one global `orderedSteps` array. |
| IMG_8265 | Resume appears unresponsive. | The continue card is allowed while an in-progress non-coach lesson is already embedded lower in Home. `resume()` can set `.inProgress` to `.inProgress`, routing to the already-selected tab without scrolling to the lesson, so there is no visible change. |
| IMG_8264 | A system “Farm update” alert interrupts an already blocking tutorial. | Advancing `.farmClaimWearable` and `.farmEquipWearable` directly calls reward mutation methods, which set `farmActionMessage` and present an alert over the coach mark. |
| IMG_8264 plus the first-run sequence | Moonlit Coat is mentioned repeatedly but not meaningfully presented. | The recommendation page, gift page, Farm lessons, and alert repeat the gift. The tour targets the generic Farm Shop card, whose default category is Ollie, while Moonlit Coat lives under Shepherd. |
| Current behavior | Continuing a lesson can claim or equip a cosmetic. | `HomeView.advanceOrientationTour()` performs claim/equip side effects before advancing. This couples education to player decisions. |

## Product decisions for this redesign

### 1. Use chapters, not a global tour

Do not display a total such as “1 of 17.” The user should only see the size of the chapter they
accepted.

#### Chapter A — Home basics (4 tips)

Offered once immediately after setup.

1. Tonight’s Wind Down plan
2. The eligible start action
3. Phone Away as a separate mode
4. The four root tabs

Header: **HOME BASICS · 1 OF 4** through **4 OF 4**.

Completion copy: **“That’s the four basics. Have a look around.”** The overlay then disappears.
Show two ordinary actions: **Explore** and **Try a 5-minute practice**. Practice remains optional
and preserves its existing reward contract.

#### Chapter B — Around the Farm (4 tips)

Do not auto-start this chapter after Chapter A. On the first user-initiated Farm visit, show a
small inline card:

- Title: **Want the four-tip Farm tour?**
- Detail: **Meet the flock, The Barn, the wardrobe, and Ollie’s Search.**
- Actions: **Show me** / **Explore on my own**

The four tips are:

1. Pasture and flock
2. The Barn and wool balance, combined into one lesson
3. Your Shepherd wardrobe and Farm Shop
4. Ollie’s Search and Search Journal, combined into one lesson

Shearing is not a mandatory tour step. Teach it through a contextual card only after the player
opens an eligible sheep. Choosing not to shear must require no “skipped shear” simulation.

#### Chapter C — Records and controls (2 contextual tips)

Do not chain these into the Farm chapter. Offer each only after the player opens the surface:

1. Settings: where the Wind Down plan and permissions live
2. Nights: where factual Wind Down, Phone Away, and practice records differ

Each card says **1 OF 1**, or omits a counter entirely. A tab visit should never immediately dim
the screen before the surface has rendered; first show the surface, then offer **Show this tip**.

#### Context-only guidance, outside chapter counts

- Five-minute practice
- Practice reward
- Moonlit Coat / wardrobe
- Shearing
- Slumber Party
- Completion/replay

Slumber Party must be taught only when the feature is available and the user opens or chooses its
card. It is not part of the universal first-run count.

### 2. Build real exploration pauses

At every chapter boundary:

- set the guide to an idle/exploration state;
- remove the dimming overlay;
- do not select another tab automatically;
- do not show another chapter prompt in the same interaction;
- allow ordinary navigation and Farm interaction;
- keep the next guide available from Settings without nagging.

An exploration pause is a persisted state, not a timed delay. Do not use elapsed time, app opens,
or engagement metrics to unlock the next chapter. Relevant user navigation is the only trigger.

### 3. Make the welcome wearable a player choice

The 2026-08-26 ADR-0018 amendment makes the Shepherd wearable independent of questionnaire
completion. Claim the selected production item immediately and keep the result screen separate.

Required flow:

1. Do not mention the coat on the recommendation page. That page should explain the Wind Down
   starting point only.
2. Reveal all three finished choices once on the gift page using the real `FarmShopItemImage`
   assets and an effect-aware preview of the person's actual Shepherd.
3. Copy: **“A little something for starting.”**
4. Present two explicit choices:
   - **Keep for later** — claims the item and leaves equipment unchanged.
   - **Wear now** — claims and equips the selected outfit or accessory after this direct tap.
5. Skipping the behavioral questionnaire must retain the same one-gift eligibility.
6. In Farm Shop → Shepherd, the item must be visible as **Welcome gift · Owned** even when its
   normal progression tier is locked. Do not show a wool price as though the player still needs
   to buy it.
7. Your Shepherd must show **Wear** / **Take off** and the equipped preview using the selected item.
8. A contextual wardrobe card may point to it once, but must not repeat the entire gift reveal.

Delete the `.farmClaimWearable` lesson from the new visible journey. Legacy persisted states at
that step should migrate to the wardrobe introduction. Keep old enum raw values decodable until a
separate compatibility decision allows their removal.

Most importantly, remove reward mutations from generic tour `Continue` handling. `Continue`,
`Back`, `Skip`, `Resume`, and chapter completion are navigation/education intents only.

## Responsive coach-mark specification

### Standard text sizes

For 375–430 point portrait widths:

- horizontal screen margin: design-system `md` or at least 16 points;
- card width: available width minus margins, never an assumed 440-point canvas;
- target: keep at least 128 points of the highlighted control visible where possible;
- coach card: target 34–42% of available height and never exceed 46% at standard Dynamic Type;
- title: at most two lines;
- message: at most three short lines; rewrite copy rather than shrinking below design tokens;
- primary action: full-width, minimum 48-point height, readable on one or two lines;
- secondary actions: a separate row below or above the primary action;
- no three-button row on compact widths;
- button text may wrap to two lines, never one character per line;
- all tap targets remain at least 44 × 44 points.

Use an adaptive composition (`ViewThatFits` or an explicit width/Dynamic Type branch):

```text
standard width                  compact width / larger type
Back   Skip       Continue      [ Continue                 ]
                                Back          Skip for now
```

Prefer a compact eyebrow such as **HOME BASICS** over “GETTING TO KNOW COUNTING SHEEP.” The app
name is already visible in shell chrome and does not need to consume two lines inside every tip.

### Large Dynamic Type and constrained height

Accessibility text must not be truncated to preserve the 46% standard-size target. For large
Dynamic Type:

- allow the coach body to scroll internally;
- keep the chapter label and action area pinned;
- keep the spotlight visible when geometry allows;
- if no non-overlapping placement is possible, use a bottom presentation with a clear
  **Show highlighted area** accessibility action rather than positioning the card off-screen;
- preserve VoiceOver order: chapter progress, title, message, primary action, Back, Skip.

### Missing or off-screen targets

A missing target must not create a giant centered modal. Route/scroll to the target once. If it
still cannot resolve after layout, show a compact non-spotlight card that names the destination
and offers **Take me there** or **Not now**. Do not mark the tip seen until the target is shown or
the user explicitly skips it.

## Resume contract

Resume must always produce a visible state change in the same interaction.

Evolve `FirstRunResumeDestination` so it identifies both destination and presentation:

- root surface;
- navigation reset requirement;
- coach target, sheet, or embedded-card anchor;
- chapter and step;
- optional scroll anchor.

Behavior:

1. The persistent continue card appears only for a genuinely paused chapter, never merely because
   the current step uses an embedded card instead of a coach mark.
2. Its title is specific: **Resume Home basics**, **Resume the Farm tour**, or **Try the practice**.
3. Tapping it resets the relevant tab to its root when needed, selects the tab, scrolls to the
   target/embedded card, and presents the lesson.
4. If the destination is already visible, Resume still scrolls/focuses or presents it.
5. If a saved legacy step no longer exists, migrate to the nearest valid chapter prompt; never
   leave a tappable no-op.
6. A small unit-testable routing result should be calculated in `Shared/`; `HomeView` applies it.

Remove the whole-card `.onTapGesture` from `FirstRunContinueCard`. It competes with its two nested
buttons and makes hit behavior ambiguous. Use only explicit button actions and accessibility
actions.

## State and migration design

Update the existing `CountingSheepOrientationState`; do not create another onboarding state
machine.

Suggested schema-6 additions:

- `activeChapter: FirstRunGuideChapter?`
- `chapterStepIndex: Int`
- `completedChapters: Set<FirstRunGuideChapter>`
- `deferredChapters: Set<FirstRunGuideChapter>`
- `presentationState: idle | offered | active | paused`
- retain existing milestones, practice IDs, contextual-tip state, and legacy `currentStep`
  compatibility fields as needed for decoding

Migration rules must be deterministic and covered for every schema-5 step:

- Home/start/Phone Away → equivalent Home chapter position.
- Practice offer/reward → practice contextual state.
- Farm steps → nearest equivalent Farm chapter position.
- Claim/equip wearable → wardrobe contextual offer; never auto-equip during migration.
- Slumber Party → deferred Slumber Party contextual card.
- Settings/Nights → corresponding one-time contextual tip.
- Completion → all universal chapters completed.
- Dismissed/skipped states stay quiet until the user explicitly resumes/replays.
- Existing reward ownership/equipment state remains authoritative and is never rewritten by
  orientation migration.

Persist after every accepted, skipped, paused, completed, or explicit cosmetic action. Preserve
`ollie.*` keys and backwards-compatible JSON decoding.

## Implementation sequence

### Phase 0 — Protect the working tree

This repository currently contains extensive unrelated uncommitted work. Before implementation:

- inspect `git status` and relevant diffs;
- do not reset, revert, or overwrite existing changes;
- keep edits confined to the files listed below unless a discovered dependency is documented;
- do not touch `project.yml`, targets, entitlements, signing, or the four-tab structure.

### Phase 1 — Shared journey model and migration

Primary files:

- `Shared/Orientation.swift`
- `Shared/FirstRunJourney.swift`
- `Tests/OrientationTests.swift`
- `Tests/FirstRunJourneyTests.swift`

Tasks:

- introduce chapter-scoped progress and presentation state;
- replace global numbering with chapter numbering;
- add pure resume routing;
- migrate every schema-5 step and status;
- remove claim/equip from educational advancement semantics;
- keep practice IDs, reward routing, and legacy decoding intact.

Do this before view work so UI behavior is driven by testable state rather than local `@State`
flags.

### Phase 2 — Responsive overlay and continue card

Primary files:

- `PhoneInTheOtherRoomApp/Views/Components/OrientationTourOverlay.swift`
- `PhoneInTheOtherRoomApp/Views/Components/FirstRunGuideCards.swift`
- `PhoneInTheOtherRoomApp/Views/HomeView.swift`

Tasks:

- implement adaptive action layout and card height budgeting;
- shorten the repeated eyebrow and chapter-scope the counter;
- add safe target routing/scrolling;
- make the continue card paused-only and destination-specific;
- remove its parent tap gesture;
- ensure embedded lessons can be focused or scrolled to;
- stop presenting alerts over a coach mark.

### Phase 3 — Chapter surfaces and exploration breaks

Primary files:

- `PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift`
- `PhoneInTheOtherRoomApp/Views/FarmView.swift`
- `PhoneInTheOtherRoomApp/Views/MoreView.swift`
- `PhoneInTheOtherRoomApp/Views/FocusStatsView.swift`
- relevant reusable Farm cards under `Views/Components/`

Tasks:

- add the four-tip Home completion handoff;
- offer, but do not auto-start, the four-tip Farm chapter;
- combine Farm lessons as specified;
- move Settings/Nights to contextual offers;
- remove Slumber Party from the universal journey;
- verify first-run content has enough bottom inset above the persistent tab bar.

### Phase 4 — Moonlit Coat autonomy

Primary files:

- `PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingRecommendationStepView.swift`
- `PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingGiftStepView.swift`
- `PhoneInTheOtherRoomApp/ViewModels/FocusRunViewModel+Farm.swift`
- `PhoneInTheOtherRoomApp/Views/FarmShopView.swift`
- `PhoneInTheOtherRoomApp/Views/FarmShopItemDetailView.swift`
- `PhoneInTheOtherRoomApp/Views/ShepherdCustomizationView.swift`
- `Shared/WelcomeReward.swift` only if an explicit-action API is needed
- corresponding WelcomeReward/Farm tests

Tasks:

- consolidate the gift into one visual reveal;
- add explicit keep/wear actions;
- remove generic advancement side effects and the delayed Farm alert;
- make the owned Moonlit Coat visible in the Shepherd Shop category regardless of tier;
- distinguish welcome-gift ownership from a wool purchase;
- deep-link the contextual wardrobe lesson to the correct owned item;
- preserve idempotent ownership and equipment behavior.

### Phase 5 — First-run responsive audit

Audit every screen reachable before the first exploration pause, not only the overlay:

- onboarding welcome/profile/recommendation/gift/schedule/quiet/protection/ready;
- Home cards and start actions;
- practice offer and completion card;
- Farm offer, wardrobe, Shop item detail, Settings tip, Nights tip;
- Slumber Party card if the feature is enabled.

Replace inflexible button rows, fixed widths, and fixed-height cards with adaptive layouts using
the existing design tokens. Do not solve overflow by reducing all fonts.

### Phase 6 — Documentation

The founder direction here supersedes the uninterrupted expanded journey. Update:

- `AGENTS.md` architecture summary wording;
- `docs/PROJECT_BRIEF.md`;
- `docs/PRODUCT_PRINCIPLES.md` only where progressive autonomy needs recording;
- `docs/ARCHITECTURE.md` orientation schema and resume behavior;
- `docs/DECISIONS/ADR-0017-progressive-guide-phone-break-and-sleep-guidance.md`;
- `docs/DECISIONS/ADR-0018-first-run-welcome-rewards.md` to clarify that the welcome gift
  remains independent of questionnaire completion and equipment is always an explicit choice;
- `docs/FIRST_RUN_COPY_INVENTORY.md`;
- `docs/FUTURE_AGENT_TASKS.md` when the implementation is complete or if follow-ups remain.

Do not preserve the old 17-step experience merely because earlier documentation described it.

## Copy changes

Apply the repository product-copy skill and keep all strings drop-in short.

| Location | Current idea | Verdict | Replacement direction |
|---|---|---|---|
| Coach eyebrow | “GETTING TO KNOW COUNTING SHEEP” | Revise | “HOME BASICS” / “AROUND THE FARM” |
| Coach progress | “1 OF 17” | Revise | “1 OF 4” within the accepted chapter |
| Home chapter end | no exploration boundary | Add | “That’s the four basics. Have a look around.” |
| Continue card | “Continue getting to know Counting Sheep” | Revise | “Resume Home basics” or the specific paused chapter |
| Continue detail | generic list of four screens | Revise | Name the exact next lesson in one sentence. |
| Recommendation coat card | repeats wearable promise | Remove | Keep this page about the Wind Down starting point. |
| Gift reveal | “A gift is waiting…” | Revise | “Moonlit Coat was added to your wardrobe.” |
| Gift actions | implicit later claim/equip | Revise | “Keep my current outfit” / “Wear Moonlit Coat” |
| Farm alert | “Moonlit Coat is waiting. Ollie can help you put it on.” | Remove | No alert after tutorial navigation; use inline status after an explicit action. |
| Farm chapter offer | none | Add | “Want the four-tip Farm tour?” / “Show me” / “Explore on my own” |

Collect and review accessibility labels at the same time. VoiceOver must announce chapter-scoped
progress and the result of an explicit wear/take-off action.

## Automated tests

At minimum, add or update tests for:

1. Each chapter reports only its own count and never the global legacy count.
2. Completing Home leaves the guide idle; it does not advance into Farm automatically.
3. First Farm entry offers the Farm chapter but does not activate it without **Show me**.
4. Dismissing a chapter stays quiet; Settings replay/resume restores it.
5. Every schema-5 step/status migrates to a valid schema-6 destination.
6. Legacy claim/equip steps migrate without changing Farm equipment.
7. Resume returns a visible presentation for coach, practice sheet, embedded card, and contextual
   tip destinations.
8. No in-progress embedded lesson causes the generic continue card to cover itself.
9. Tour Continue/Back/Skip do not mutate owned items, equipment, wool, sheep, or reward ledgers.
10. Choosing a welcome item owns and claims it idempotently whether the questionnaire was
    completed or skipped.
11. **Wear now** equips the selected accessory or outfit in its correct slot; **Keep for later**
    preserves the current Shepherd appearance.
12. An owned gift stays visible in Shepherd Shop presentation despite its normal tier lock and is
    labelled owned rather than purchasable.
13. Existing practice reward, Wind Down guarantees, Phone Away guarantees, and Codable legacy
    tests remain green.

## Preview and device QA matrix

Add representative `#Preview`s for the overlay and each new card, including non-happy paths.

| Device / setting | Required proof |
|---|---|
| Physical iPhone 12, standard text | No clipped or vertically letter-wrapped buttons; target remains visible; Resume visibly routes; all chapter breaks work. |
| iPhone SE (3rd gen) simulator, standard text | Compact action stack fits; all content is reachable; tab bar does not cover CTAs. |
| iPhone 12/13-sized simulator, standard text | Baseline screenshot set for all four Home and Farm tips. |
| Current large iPhone simulator | Layout does not become excessively wide; card retains readable measure. |
| iPhone 12, Dynamic Type XL and AX3 | No truncated copy or unreachable action; internal scrolling and VoiceOver order work. |
| Bold Text + Increase Contrast | Borders, selected state, and button hierarchy remain legible. |
| Reduce Motion | No required information depends on coach transition animation. |
| VoiceOver | Spotlight target, progress, copy, and actions are announced once in logical order; focus moves to the presented lesson after Resume. |

For each screenshot that originally failed, capture an after-state at the same logical step and
compare it directly. IMG_8261/8262 are the primary compact-button regression references;
IMG_8264 is the no-stacked-alert/no-auto-equip reference; IMG_8265 is the Resume reference.

## Validation commands

After implementation, run the repository’s required gate with an available simulator name:

```bash
xcodegen generate
xcodebuild build \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoom \
  -destination 'generic/platform=iOS Simulator' | tail -20
xcodebuild test \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoom \
  -destination 'platform=iOS Simulator,name=iPhone 15' | tail -30
```

Also run the non-trivial change through `docs/PLAYBOOKS/pre-merge-review.md`. Do not claim the
responsive fix complete without the physical iPhone 12 pass because the defect was reported there.

## Acceptance criteria

The work is complete only when all are true:

- No screen shows “x of 17” or forces the full journey in one sequence.
- The only automatic initial coach sequence contains exactly four Home tips.
- Finishing a chapter returns to a fully interactive app and does not immediately start another.
- Later guidance is contextual, opt-in, replayable, and quiet after dismissal.
- Every Resume tap visibly navigates, scrolls, or presents the promised lesson.
- No first-run button clips, overflows, or wraps one character per line on physical iPhone 12.
- At standard text size, a coach mark does not occupy more than 46% of available height and the
  highlighted feature remains meaningfully visible.
- Accessibility text remains usable without truncation, even when the standard-size height target
  must be relaxed.
- Moonlit Coat is revealed once with real art, is visible as owned in Shepherd Shop/wardrobe, and
  is equipped only after an explicit **Wear Moonlit Coat** or later **Wear** action.
- Continuing, skipping, resuming, or completing education never performs a Farm economy/cosmetic
  action.
- Existing persisted orientation, reward, Farm, practice, and search data decodes without loss.
- Build, unit tests, previews, and the physical iPhone 12 QA matrix pass with recorded results.

## Luna High handoff prompt

> Implement `docs/ONBOARDING_PROGRESSIVE_GUIDE_OPTIMISATION_PLAN.md` as a coherent vertical
> slice. Read `AGENTS.md`, the canonical product docs, ADR-0017, ADR-0018, and the product-copy
> skill first. The repository has extensive unrelated uncommitted work: preserve it, inspect
> overlapping diffs, and do not reset or revert anyone else’s edits. Start with the schema-6
> Shared journey model and migration tests, then build the adaptive overlay, exploration pauses,
> deterministic Resume routing, and explicit Moonlit Coat choice. Do not touch `project.yml`,
> targets, entitlements, signing, backend behavior, or tab structure. Generic tutorial navigation
> must never mutate Farm state. Run the required build/tests and report real physical iPhone 12 QA
> separately from simulator evidence.
