# Mobbin research — Counting Sheep's first night

14 September 2026. Research brief and proposed experiments; not an implemented redesign
or a change to product direction.

## Reference collection

[Counting Sheep — First Night](https://mobbin.com/collections/733062bf-b31e-4dd3-8f6d-ec6f7428c7ef/mobile/flows)
is a private Mobbin collection created for this work. It contains three saved flows.
The annotations below are the durable record of why each reference was selected.

| Reference | Observed pattern | Application to Counting Sheep |
| --- | --- | --- |
| [Opal — Setting up an account](https://mobbin.com/flows/55055eaa-2000-42a0-8ace-ac95665dfb18), 9 screens | The inspected opening screens explain Screen Time access beside a permission illustration, then present app selection with an empty-selection state and unavailable continuation. | Make authorization and app selection visibly distinct steps in the first start sheet. Use Counting Sheep's actual readiness state and privacy contract. |
| [Headspace — Today](https://mobbin.com/flows/0ceaf050-62dc-4491-be38-aa0c94093e59), 3 screens | Activities are grouped by time of day. Compact cards pair an activity with its type and duration; favorites/history are secondary entry points. | Keep the chosen evening invitation near the next Wind Down action, with morning information grouped separately. Preserve optional invitations without completion checkmarks. |
| [Structured — Onboarding](https://mobbin.com/flows/88def011-f342-45ad-9597-764a72338f2d), 20 screens | The inspected opening and planning screens move from welcome to a concrete plan. Wake and bedtime questions use distinct sun/moon scenes, with persistent bottom actions and visible skip controls. | Give bedtime, wake time, and quiet durations a clear visual relationship. Retain Counting Sheep's short plan-first route and existing native time pickers. |

These are visual observations from Mobbin's captured versions. They are not evidence of
conversion improvements, accessibility quality, or the competitors' current runtime behavior.
Opal and Structured were inspected at the relevant portions of their longer sequences;
the complete flows remain saved for subsequent review. No third-party artwork or copy was
imported into the app.

## Current journey and findings

The fresh route is two skippable story pages, schedule/reminders, one optional evening
activity, then review and Go to Home. Protection setup is deferred until an actual start.
The optional profile, gift, and account chapter remains separate. Preserve this contract in
[Product direction](../PRODUCT_DIRECTION.md#first-run-and-guidance).

Source inspection establishes the following:

- [OnboardingFlowView](../../PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingFlowView.swift)
  already has a bottom action bar and returning-user sign-in. Keep these strengths.
- [OnboardingQuietStep](../../PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingQuietStepView.swift)
  already offers one activity, custom input, and an optional expanded routine. More questions
  are unnecessary for this research slice.
- [OnboardingReadyStep](../../PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingReadyStepView.swift)
  combines a conceptual three-phase timeline, five absolute-time rows, a routine card, a
  readiness card, and two handoff explanations. The timeline and rows contain complementary
  information, but distributing it across separate blocks increases reading effort.
- [WindDownStartSheet](../../PhoneInTheOtherRoomApp/Views/Components/WindDownStartSheet.swift)
  puts the start and cancel buttons inside the scrolling content after protection, social,
  campfire, and Lock Screen controls. Its protection card groups authorization-required,
  no-selection, revoked, and runtime-failure states under the same generic setup action.
  These are source findings; visibility and comprehension on the current build need testing.

## Recommended first experiment: make the next action clear

Prototype a state-aware first-start sheet. Keep the existing coordinator, admission checks,
consent rules, and start transaction.

| Current state | Proposed primary action | Content that should remain visible |
| --- | --- | --- |
| Authorization required | Request Screen Time access | Why access is needed, what will be limited, and when |
| Authorized, selection empty | Open Apple's app/category picker | A non-empty selection is needed; essential access remains the person's choice |
| Ready | Start using the existing mode-specific action | Selected item count, phone placement invitation, protection period |
| Denied/revoked | Existing permission repair route | The actual blocking state and a clear way back |
| Runtime failure | Existing repair route | Failure context; setup-ready wording must not imply protection was applied |
| Unavailable | Explain unavailability and offer exit | No enabled start and no false protection evidence |

Give the primary action a stable bottom location, using the existing onboarding action-bar
approach as the local design reference. Keep all content scrollable above it. Returning from
the permission dialog or picker advances readiness only: it must never automatically start
the session. NFC keeps its separate existing confirmation behavior. Preserve visible sharing
choices and the consent summary wherever relevant; collapsing controls must not hide an
unaccepted agreement or change the saved choice.

**Acceptance:** On a small iPhone, a fresh user can identify the current blocking step and
the next action without hunting through optional controls. Repeat with large text, denied
permission, empty selection, runtime failure, and ready/NFC states. The footer must not cover
content. VoiceOver order must explain the blocker before its action.

## Second experiment: one readable plan review

Combine the conceptual timeline and clock information into three ordered sections:
before bed, overnight, and morning. Include all existing boundary times and quiet durations;
do not remove information simply to shorten the screen. Place chosen invitations with the
corresponding phase, and keep protection/reminder readiness in a compact summary.

Keep Go to Home as the save action. It must not claim the draft is already saved or start
a session. Preserve the optional tour. This is a presentation experiment with no schedule,
reward, or persistence changes.

**Acceptance:** After a brief look, a participant can explain when Wind Down starts, when
the morning window ends, which activity they chose, whether protection needs setup, and
what Go to Home does. Include no-activity, reminders-denied, next-day, and large-text cases.

## Use the remaining three months

Work relative to the offer's actual expiry date; it has not been verified here. These are
suggested research batches, not scheduled tasks or automations.

| Period | Question | Concrete output |
| --- | --- | --- |
| Weeks 1–2 | Can someone plan and start their first night confidently? | This collection; two small prototypes; observed first-use findings |
| Weeks 3–4 | Does the morning receipt explain the saved outcome and where to go? | Three reward/return references; one receipt refinement if testing supports it |
| Weeks 5–6 | Can someone understand sheep, clues, carried credit, and the Search Journal? | A focused Farm discovery comparison, preserving the existing ledgers |
| Weeks 7–8 | Can someone preview, purchase, and equip the intended item? | Shop comparison covering owned/equipped/unaffordable states |
| Weeks 9–10 | Does a Slumber Party invitation explain joining and sharing? | Invite/consent/empty-state comparison against the current social contract |
| Weeks 11–12 | Which changes helped, and which patterns should we reuse? | Updated decisions, source links, and a concise local reference index |

For each batch, start with one user question and inspect about three strong references.
Record the exact flow URL, captured version, observed pattern, proposed adaptation, and a
specific way to test it. A reference earns its place by supporting a decision. Save the
reasoning in the repository so the useful work survives the subscription.

## Reusable Codex research prompt

> Read the current Counting Sheep product direction and the code for [journey]. Use Mobbin
> to inspect three relevant iOS flows for [specific question]. Prefer callable Mobbin tools;
> if unavailable, use the signed-in browser and disclose that fallback. Include exact source
> links. Separate observed screen behavior, code findings, and hypotheses. Recommend the
> smallest useful change using our existing theme and components. Preserve the current
> product rules and identify an acceptance scenario. Update this research record with the
> decision and evidence. Do not infer conversion or clinical benefits from screenshots.

For implementation, scope a separate instruction to the selected experiment, then follow
the repository's copy, SwiftUI, build, test, and visual-validation requirements. Reinspect
the working tree first: the start sheet and Home were already under active development
during this research.

## Evidence and limits

- Created the collection with Private enabled; verified all three flow titles in its contents.
- Mobbin OAuth login succeeded in the preceding setup turn. Mobbin tools were absent from
  this task's callable inventory, so this research used the existing authenticated Chrome tab.
  A successful MCP search has not yet been verified.
- Inspected the source files linked above, the current onboarding route, and relevant backlog
  entries. This was not a new Simulator or physical-device review.
- Delivered research documentation only. No app source, project configuration, backend,
  production deployment, distribution, or reward behavior changed in this pass.
