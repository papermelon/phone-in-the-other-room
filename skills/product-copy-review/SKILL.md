---
name: product-copy-review
description: Write or review release-facing Counting Sheep copy for voice, accessibility, and truthful evidence or sharing claims. Excludes internal identifiers and debug-only mocks unless requested.
---

# Skill: Product Copy Review

## Description

Write and review release-facing copy in Counting Sheep's voice: warm, brief,
Ollie-flavoured, and comfortable to read at night. Use for any string a person can
see or hear, including buttons, states, notifications, accessibility text, permissions,
consent, recovery, empty states, and App Store text. Exclude internal compatibility
names and debug-only mock screens unless the task explicitly includes them.

Authority and validation follow [AGENTS.md](../../AGENTS.md). Consult only the relevant
product or capability contract when the changed claim needs it.

## Tone principles

1. **Ollie's farm, at dusk.** Warm, adult, concise, and lightly storybook-like. Sound
   like a capable companion, not a children's narrator, coach, clinician, or brand voice.
2. **Tired-reader rule.** The reader is in bed at 11pm. Short sentences. One idea per
   line. If a line needs re-reading, rewrite it.
3. **Celebrate, never judge.** Success is celebrated softly; failure gets sympathy and a
   fresh start. The app has no disappointed voice.
4. **Concrete farm imagery over abstraction.** Ollie watches the ritual, searches for
   missing sheep, and waits at the gate. Story language can invite someone to put their
   phone in another room; it cannot turn an unobserved action into receipt evidence.
5. **Honest and humble.** Name the timer, record, self-report, or observed shield event
   that supports a claim. Never infer physical placement, sleep, screen avoidance, or
   routine completion from elapsed time or permission state.

## Hard rules

- **No guilt or shame:** never "you failed", "you gave in", "broke your streak",
  "disappointed", or a sad mascot punishing the user.
- **Judge pressure in context:** urgency, scarcity, stakes, anticipation, and return
  motivation are product tools, not banned word classes. Assess what the specific copy asks
  the person to do, whether the mechanic is truthful, and how it feels at that point in the
  ritual. Revise manipulative, misleading, or dark-room-disruptive pressure; do not reject
  wording merely because it creates anticipation or encourages a return.
- **No medical claims or overpromising:** never "improves sleep", "fixes insomnia",
  "scientifically proven". Allowed: "helps you wind down", "builds a phone-away habit".
- **No invented evidence:** "Put your phone in another room" is an invitation. A timer
  can show elapsed minutes; an app or Device Activity record can show its own observed
  shield events; neither proves continuous placement, sleep, complete screen avoidance,
  or that a suggested routine happened.
- **No permission/enforcement substitution:** authorization and a non-empty Screen Time
  selection mean setup is ready. They do not prove that protection applied or stayed
  active. Distinguish ready, applying, observed, partial, unavailable, and failed states.
- **No privacy or capability overclaim:** say what is local, what is shared, with whom,
  and under which agreement or capability. Do not present undeployed, unconsented, or
  capability-gated behavior as current. A self-reported or app-recorded social receipt
  is not independent verification.
- **No unsupported enforcement claim:** describe only the apps/categories, interval, and
  fail-open behavior the current system can enforce. Do not imply remote family control,
  exact-app visibility, moderation outcomes, or a shield that Counting Sheep cannot attest.
- **No productivity jargon:** never "crush", "grind", "maximize", "optimize", "streak
  goals". This is a bedtime app, not a performance tool.
- **Bedtime/sleep wording:** use factual records such as completed Wind Downs and recorded
  before-bed minutes. Do not call timer time "sleep" or "phone-free" unless the surface
  clearly identifies it as a plan or invitation rather than observed evidence. Evening
  copy should get quieter, not louder; save exclamation marks for the morning, and use at
  most one.

## Before / after examples

| Situation | Wrong | Right |
|---|---|---|
| Early-ended run | "You broke your streak!" | "Ollie kept your spot warm. Tonight's a fresh start." |
| Missed night | "You lost your 6-day streak." | "The pasture was quiet last night. Ready when you are." |
| Wind Down completed | "The phone slept in the other room." | "Wind Down finished. 30 before-bed minutes recorded." |
| Start CTA | "Optimize your evening" | "Put phone away" |
| Shield applying | "Your apps are protected." | "Counting Sheep is applying your selected-app limits." |
| Shield evidence unavailable | "Protection verified." | "Protection could not be confirmed. Your timer record is still accurate." |
| Stats header | "Screen time reduced 47%" | "9 completed Wind Downs · 270 before-bed minutes" |
| Marketing | "Scientifically proven to improve sleep" | "A gentler way to wind down without your phone" |
| Empty rewards | "No rewards yet. Get started!" | "The shelf is waiting for its first treasure." |
| Notification | "You haven't started a run today!" | (Don't send this notification at all.) |

## Review procedure

1. Collect every new/changed user-visible string (including accessibility labels,
   notification text, and alert buttons).
2. Identify the evidence source for every completion, protection, placement, sleep,
   screen-avoidance, social, and sharing claim. Check factual, medical, privacy,
   enforcement, capability, and non-judgment constraints as hard requirements. Evaluate
   pressure, urgency, stakes, anticipation, scarcity, and return motivation through their
   concrete context and effect rather than a generic blacklist.
3. Check tone: read it aloud as Ollie's narrator; flag anything clinical, corporate,
   hyped, or guilt-tinged.
4. Check the tired-reader rule: sentence length, one idea per line.
5. Check context: evening strings must be calm; celebration belongs to morning surfaces.
6. Review visual text and accessibility text together. VoiceOver must express the mode,
   state, evidence, value, and action without relying on colour or an icon.
7. For a multi-string audit, use a table of location → current → verdict → revision.
   For a small edit, provide the corrected wording and any material rationale directly.
   Suggestions must be drop-in ready; an implementation request includes applying them.

## Acceptance criteria

- Zero hard-rule violations ship.
- Revisions preserve meaning and fit the UI space (roughly similar length unless the
  original was too long).
- Ollie is referenced naturally, not forced into every line.
- Invitations and story imagery remain lively without being presented as observed facts.
- Timer, independent ledgers, runtime evidence, and capability-gated sharing stay distinct.
- App Store / marketing copy makes no outcome promises.
