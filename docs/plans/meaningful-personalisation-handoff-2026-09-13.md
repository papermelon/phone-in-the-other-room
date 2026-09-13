# Meaningful personalisation — detailed implementation handoff

Drafted 13 September 2026. This document is the requested handoff prompt, not an implementation or deployment of personalisation or AI. The founder approved the accompanying morning/countdown and completion-screen redesign. They requested that the meaningful personalisation loop be designed separately and that OpenAI API credits be assessed. No live AI calls, purchases, new third-party data sharing, or backend activation are authorised by this document alone.

## Prompt for the next implementation task

Build a useful, optional personalisation loop for Counting Sheep: learn what the person explicitly wants from Wind Down and Screen-Free Morning, help them make a realistic plan, collect occasional feedback, and offer a small adjustment that they can understand and choose. The outcome is a better-fitting routine, not more time spent in the app or more questionnaires completed.

Start with the local loop. Treat the AI-assisted variant below as a separately gated experiment. Present any genuinely unresolved product decisions with a concrete recommendation after completing independent preparation. Preserve unrelated working-tree changes. Do not commit, push, deploy, distribute, spend API credits, or add dependencies/entitlements without applicable authorisation.

### Context and current work to preserve

- Product: Counting Sheep; Ollie is the person's capable border collie. The primary ritual is Wind Down, followed by the independent Screen-Free Morning window. Phone Away is a separate secondary use case. Keep Home, Nights, Farm, Settings.
- The founder rejected the active timer's generic Purpose menu. Its options mixed activities and motivations, and did not contribute to ongoing personalisation. Do not reintroduce that menu under another label.
- `QuietPurposeCue` is a temporary, occurrence-scoped value for the blocked-app intervention. It is not a longitudinal goal profile. The active-screen selectors have been removed; legacy decoding and the shield's default cues remain supported. Do not interpret historical cue choices as confirmed motivations.
- The morning UI now reuses the Ollie-and-sheep sunrise scene with its independent occurrence clock. It has a countdown, compact frozen morning ideas, Brief Access information only when used, and expandable protection details. Keep admission, NFC, emergency exit, shielding, and settlement in their existing owners.
- Completion now leads with a saved search outcome or Farm progress, uses one compact timer record, and places technical detail behind disclosure. Only a linked morning belongs in that Wind Down receipt. The founder chose “Pre-Sleep Wind Down” for the timer segment before the planned bedtime; it does not measure sleep onset. Do not add a compulsory questionnaire to the reward screen.
- The existing local habit implementation already stores optional planning cues, preparation, smaller activities, placement intentions, and evening starting-ease/obstacle reflections. Build on it.
- There is also an optional onboarding starting-point questionnaire and `OfflinePurposeProfile`. Audit their purpose, persistence, and consumers before creating overlapping profiles. The existing starting-point copy says those answers do not change the plan; change that claim only when an actual accepted change is implemented.

### Read these references selectively

Read `AGENTS.md`, relevant sections of `docs/PRODUCT_DIRECTION.md`, `skills/swiftui-feature/SKILL.md`, and `skills/product-copy-review/SKILL.md`. For the actual changes, read:

- `docs/plans/wind-down-habit-loop-2026-09-08.md`
- `docs/DECISIONS/ADR-0019-independent-wind-down-and-morning-quiet.md`
- `docs/DECISIONS/ADR-0020-cumulative-farm-credit.md`
- `docs/DECISIONS/ADR-0023-account-owned-farm-sync.md`
- `docs/plans/farm-save-contract.md` if any persistence/sync boundary is involved

Inspect the following code rather than assuming this handoff is an up-to-date repository map:

- `Shared/WindDownHabit.swift`, `Shared/OfflinePurpose.swift`, `Shared/QuietTimeShieldPresentation.swift`
- Existing onboarding profile/draft models and `Views/Onboarding/OnboardingPersonalizationView.swift`
- `Services/PersistenceService+WindDownHabit.swift`
- `ViewModels/FocusRunViewModel+WindDownHabit.swift` and its account/editing identity gates
- `Views/Components/WindDownHabitHomeCard.swift`, `WindDownHabitReflectionCard.swift`, `WindDownHabitSupportEditor.swift`
- `Views/FocusRunSetupView.swift`, `Views/ScreenFreeMorningView.swift`, `Views/CompletionView.swift`
- `Shared/IndependentMorningSettlement.swift`, `Shared/ScreenFreeMorningPresentation.swift`, `Shared/HomeReceiptRouting.swift`
- Existing relevant tests, including `Tests/WindDownHabitTests.swift`

Do not load the entire backlog, introduce another bedtime state machine, or copy legacy requirements over current founder decisions.

### 1. Define the useful questions and their consequences

Keep goals, activities, constraints, and observations distinct. Every question must have a specific, visible use. If an answer only changes decorative copy, do not ask it in the initial flow.

**Motivation, chosen occasionally:** “What would you like to change about your mornings?” Proposed examples: less automatic scrolling, a less rushed start, time for myself, being present with others, or my own reason. For evenings, offer mode-relevant alternatives such as making room to unwind, putting the phone down at the intended time, or making time for a chosen activity. Test these labels with users; they are starting hypotheses, not an exhaustive taxonomy.

Choose one primary goal to start. Allow editing, a personal answer, skipping, and clearing. Never force a custom answer into a poorly fitting category. Keep an unclassified custom goal useful as written. Do not assign a personality type, diagnose a condition, or infer a motivation from brief phone access.

**Plan, chosen before the ritual:** “What would you like to do before checking your phone?” Reuse the existing morning ideas and custom activities. Keep two short morning ideas as invitations, with no completion tracking implied. A useful context may be “After I open the curtains…” or an existing daily event. Plan timing and duration remain explicit settings, independent of the goal.

**Feedback, occasional:** “Did this morning give you the start you wanted?” Proposed answers: Yes / Partly / Not today / Not sure. When the person wants to add more, ask what got in the way: timing, too much to fit in, needed the phone, activity did not appeal, forgot, or something else. Include a way to say the plan worked without collecting an obstacle. Do not score skipped answers as negative outcomes.

Reuse or extend the existing evening ease/obstacle reflection without duplicating it. Do not ask the same question in Nights and completion for the same occurrence/day. Feedback about general evenings without a session must remain possible and must not be silently linked to an arbitrary run.

### 2. Place the loop in the product

- Offer one optional goal and activity while reviewing a plan, or from a discoverable “What I’m working toward” entry in Settings/Plan. Do not block the first run or returning account access.
- The active countdown is for glancing and leaving the phone alone. It shows the frozen plan, not a form, chatbot, or repeated motivation prompt.
- Put feedback in Nights or a dismissible later Home invitation. The reward remains available regardless of feedback, and Done always works immediately.
- Initial cadence proposal: no modal auto-prompt; at most one passive reflection invitation per mode per seven-day period, plus an always-available manual entry. Suppress automatic invitations during an active ritual, after a dismissal for the rest of that period, and when the same period is already answered. These are experiment defaults, not scientifically established thresholds.
- Show at most one adjustment suggestion at a time. “Why this suggestion?”, “Review change”, “Keep my plan”, and dismissal must be understandable. Do not put implementation terminology in this UI.
- Use the shared content-fitting guide/sheet components, normal readable body typography, existing design tokens, accessible labels, and a usable large-text layout. Avoid recreating the dense receipt problem.

### 3. Make adaptation specific and transparent

Implement an auditable local rules baseline before adding AI. Produce a bounded suggestion object with an action identifier, exact evidence references, reason, target plan revision, and expiry. Support “no suggestion” as a good result.

Example mappings to validate:

| Explicit feedback | Useful offer | Required guard |
| --- | --- | --- |
| The morning felt rushed repeatedly | Review a shorter morning window or a different start time | The person chooses the exact change; never edit an active occurrence |
| I needed my phone for communication | Review selected apps and what must remain available | Do not imply the app knows exact selected-app identities or auto-disable protection |
| Too much to do | Reduce the ideas to one appealing activity | Keep timing unchanged unless separately reviewed |
| I forgot to begin | Link the ritual to a familiar cue; optionally review an already-supported reminder | Do not silently enable reminders or automatic starts |
| The chosen activity was unappealing | Swap to another chosen or custom activity | Do not interpret noncompletion as dislike |
| It worked well | Keep the plan; reduce prompting | No escalating target or harder routine by default |

Repeated-feedback suggestions should initially require at least two matching explicit reports from distinct days in a recent window, and a current compatible goal/plan. A single explicit request for help can receive immediate support without pretending there is a trend. Use actual counts and dates internally; explain relevant evidence in ordinary language, for example “You said the last two mornings felt rushed.” Do not imply statistical significance, causation, improved sleep, or verified screen avoidance.

After the person accepts an adjustment, optionally ask later whether it helped. Store the relationship between suggestion, reviewed plan change, and subsequent feedback. A saved plan revision is not proof that the person followed it. Retire stale suggestions after a goal/plan/account change. Do not keep offering rejected changes.

### 4. Data and ownership contract

Propose concrete model names after inspecting the code. At minimum, distinguish:

- A versioned, user-confirmed goal: stable ID, mode, optional category, optional bounded personal wording, selected/edited time, active/archived state.
- A plan-to-goal association and revision: what the person intended at that time. Preserve the run's immutable routine snapshot.
- A reflection: stable ID, civil day and time-zone context, optional occurrence ID only when known, goal/plan revision, explicit answer, optional obstacle. No answer is unknown.
- A suggestion: stable ID, rule/model/prompt version, evidence IDs, approved action ID, target revision, expiry, and proposed/accepted/dismissed/superseded state.
- A reviewed adjustment: exact old/new values and plan revision, with optional later self-report. Never mutate historical records.

Follow the existing device-local, account-scoped habit persistence contract first. Guest remains a separate local scope. Partition by verified immutable account identity; invalidate drafts, pending requests, cached suggestions, and asynchronous responses on account/goal/plan changes. Handle relaunch, timezone travel, duplicate saves, stale editors, and corrupt fields without erasing healthy data.

Do not append these fields to private Farm sync or Slumber Party contracts. Cross-device personalisation sync would need its own reviewed payload, consent/ownership, deletion, and migration design. Keep compatibility with old missing fields; do not convert legacy Purpose selections into a confirmed goal. Offer existing relevant profile wording for the user to confirm instead of silently adopting it.

Allow viewing/editing the active goal, deleting reflections, clearing suggestions, and turning invitations off. Removing a goal must invalidate dependent suggestions without erasing unrelated timer/Farm history. Save the minimum necessary local evidence. Propose a finite retention policy for detailed suggestion evidence and obtain a concrete product decision before introducing remote retention.

### 5. Assess the OpenAI API experiment

**Recommendation:** API credits can be suitable for a small, optional language feature once the local loop is useful. They are not necessary for basic personalisation. The first experiments worth funding are:

1. Turn the person's own short description into a proposed goal/constraint mapping that they confirm, including an unknown/custom option.
2. On request, express a prevalidated adjustment in warm, concise language grounded in their explicit feedback.
3. Optionally summarize a few recent self-reports during a user-initiated review, with factual evidence references.

Do not fund a chatbot on the timer, a call every time Home opens, generic daily motivational prose, or AI-based timer/reward/protection decisions. Do not build an agent with device-control tools, an open-ended therapist, or a persistent remote conversation history for this slice. The provider model does not become the product's memory: the app owns the explicit profile and feedback history.

First demonstrate a measurable advantage over local templates using synthetic cases and a small consenting pilot. Useful measures include faithful goal interpretation, suggestion relevance, whether people understand why it was offered, accepted and later helpful adjustments, dismissal burden, latency, and cost. More app opens or longer chat sessions are not the success criteria.

#### API architecture if the experiment is authorised

Use the existing approved backend architecture: authenticated app request → bounded Supabase Edge Function → OpenAI Responses API → server validation → app review UI. Use built-in HTTP/fetch and the existing approved client transport; no new SDK is required. A provider key belongs only in server secrets, never in the iOS bundle, App Group, or a client-supplied field. Model, output limits, rules, quotas, and prompts are server-controlled.

Send only a minimal, explicitly disclosed payload: the selected goal/wording if permitted, relevant plan constraints, a few selected self-reports/coarse counts, and permitted suggestion/action IDs. Do not send raw Health samples, exact Screen Time/app selections, notification content, emergency-exit text, social data, exact nightly timestamps, or the Farm document. Treat all user text as untrusted data rather than instructions.

Use a versioned strict Structured Outputs schema. Suggested response fields: status (`suggestion`, `no_suggestion`, `needs_clarification`), candidate goal ID if relevant, permitted action ID, evidence IDs, short explanation, and at most one clarification. The model can propose only actions selected as eligible by deterministic code. Validate evidence IDs, enum values, string bounds, plan revision, and account ownership again after the response. A valid JSON schema is not proof that a suggestion is truthful or suitable.

No model response may edit a schedule, start/finish a run, change authorization/selection, unlock apps, grant rewards, or update a user's goal without their review. Use no tool execution in this experiment. Do not expose chain-of-thought; show a short reason grounded in the provided evidence.

Handle refusal, incomplete output, invalid schema, invented evidence, timeout, offline state, rate limits, provider outage, expired/revoked credentials, and budget exhaustion. Fall back to the deterministic local suggestion or no suggestion. The ritual and Farm must remain fully usable. Cancel or discard in-flight results after account switch/sign-out, and fence responses against the request's identity, consent version, goal, and plan revision.

Use foreground requests with `store: false`, no server-side conversation object, and no background polling for this small feature. That setting is not a promise of zero provider retention. OpenAI documents that API data is not used for model training by default unless opted in, while abuse-monitoring logs may be retained for up to 30 days, with stated exceptions. Clearly explain the actual backend/provider handling before sending personal wording. Do not claim all habit data stays on the phone when AI processing is enabled. [Official data controls](https://developers.openai.com/api/docs/guides/your-data)

Provide a separate AI choice with a useful local alternative, request minimisation, an app-side disable/delete path, and a documented server/provider deletion boundary. Do not silently opt users into provider data sharing or training to obtain discounted/free tokens. Verify project data-control settings rather than assuming them. [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs), [production guidance](https://developers.openai.com/api/docs/guides/production-best-practices)

#### Candidate models and illustrative costs

Official documentation checked on 13 September 2026 identifies `gpt-5.6-luna` as a cost-sensitive model supporting Responses and Structured Outputs, including a `none` reasoning setting. Start the bounded extraction/suggestion evaluation there, with `gpt-5.4-mini` as a comparison candidate if quality is insufficient. Choose on held-out evaluation results, not model name. Recheck availability, rates, supported parameters, and account access when implementation starts. [Luna model documentation](https://developers.openai.com/api/docs/models/gpt-5.6-luna)

The following uses standard short-context prices, 2,000 uncached input tokens and 400 total billed output tokens per request, including any reasoning tokens in that output allowance. It is a planning example, not measured application usage:

| Candidate | Input / output per million tokens (USD) | Example request | 1,000 users × 4 requests/month | 10,000 users × 4 requests/month |
| --- | --- | --- | --- | --- |
| GPT-5.6 Luna | $0.20 / $1.20 | $0.00088 | $3.52 | $35.20 |
| GPT-5.4 mini | $0.75 / $4.50 | $0.00330 | $13.20 | $132.00 |

Formula: `(input_tokens × input_rate + billed_output_tokens × output_rate) / 1,000,000`. These examples exclude cache-write charges, retries, backend hosting, taxes, and any extra calls. GPT-5.6 cache writes have their own charge; measure real token accounting. Do not equate short displayed text with a bound on billed reasoning. [Official pricing](https://developers.openai.com/api/docs/pricing)

Existing OpenAI API credit could fund this pilot if it is usable in the intended API project. This task did not inspect the founder's balance, terms, expiry, or billing configuration. Do not confuse API credit with ChatGPT/Codex subscription usage. Before enabling real calls, confirm the intended project, permitted spend, remaining credit/expiry, model availability, and what should happen when credit is exhausted. Do not enable purchases or auto-recharge.

Proposed conservative pilot controls: at most four total generated requests per user per month, at most one per day, plus a founder-approved hard global spend ceiling. Count all AI entry points and retries, not just the weekly summary. Implement server-enforced quotas with atomic reservation, bounded inputs/outputs, deduplication/cached responses by request identity, a kill switch, and fallback. Dashboard alerts are useful, but application-side enforcement should own the hard stop. Keep logs to operational metadata such as latency, tokens, estimated cost, result status, and template/model version; do not log personal prompts or responses by default.

### 6. Delivery phases

**Phase A — local usefulness:** inventory existing profiles and fields; propose the smallest unified goal/plan/reflection model; implement account-safe persistence and optional UI; implement deterministic suggestion rules and acceptance through the existing editor; cover migration and non-happy paths. Update owning product decisions and copy. Do not call the OpenAI API.

**Phase B — offline AI evaluation:** prepare synthetic cases, strict schema, prompts, validators, a local baseline, and a reproducible scorecard. Request a concrete bounded API experiment budget only when these are ready and an actual paid run is needed. Compare candidate models, measure real input/output/reasoning/cache usage and latency, and report whether the model improves the experience enough to justify external processing.

**Phase C — optional pilot, only if approved:** implement the authenticated backend boundary, actual informed AI choice, quotas, kill switch, resilient fallback, privacy documentation and deletion handling. Deploy/enable only with specific authorisation. Do not describe source implementation as a launched feature or a successful habit intervention.

### 7. Acceptance and validation

Use meaningful domain/persistence tests and representative previews. The founder deferred full verification during the surrounding visual-edit session; record which checks were run and which remain. Before eventual merge/release, perform the applicable repository merge gates and device acceptance on the actual final source. Do not repeat successful matching checks merely because another document links them.

Required cases include:

- New/returning/guest user; skipped or cleared goal; custom goal; ambiguous goal; no history; sparse or conflicting feedback; an unchanged successful routine.
- Independent morning with and without a linked Wind Down; no implicit change to Wind Down rewards, morning eligibility, or protected intervals.
- A night-shift worker, irregular schedule, caregiver needing communication, accessible-nearby placement, needed-phone feedback, and “Not sure.” Avoid assuming everyone wakes at 7 AM or can remove all phone access.
- Multiple feedback entries on a civil day, travel/DST, stale editing, goal/plan revision changes, accepted/rejected/expired suggestions, and repeated requests without duplicate suggestions or billing.
- Account A → sign-out → guest → account B while a draft/request is open; no content or late response crosses owners. Corrupt storage must not overwrite healthy records.
- Large Dynamic Type, VoiceOver reading/action order, Reduce Motion, compact screens, dark-room comfort, and controls that remain reachable with long text.
- AI prompt injection in personal wording, wrong action/evidence IDs, incorrect durations, invented trends, medical/diagnostic claims, moral judgments, invalid/refused/truncated output, network failure, provider key rotation, and quota exhaustion.
- A deterministic baseline versus AI scorecard. Zero critical privacy/ownership/action-authority failures in the evaluation set; report relevance/faithfulness/helpfulness failures rather than hiding them behind an overall average. Synthetic evaluation cannot establish real-world habit improvement.

Deliver: implemented local code and tests, a concise user-flow demonstration, data/migration decisions, evidence for checks, the AI evaluation recommendation and cost model, precise deployment status, and concrete unresolved items in `docs/FUTURE_AGENT_TASKS.md`. If AI does not outperform the local baseline, recommend keeping the local implementation and retain the experimental harness rather than shipping unnecessary calls.
