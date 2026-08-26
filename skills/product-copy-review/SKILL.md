# Skill: Product Copy Review

## Description

Write and review user-facing copy in Counting Sheep's voice: warm, brief, Ollie-flavored,
bedtime-safe. Use for any string a user can see — buttons, states, notifications,
onboarding, empty states, App Store text.

## Tone principles

1. **Ollie's farm, at dusk.** Warm, gentle, lightly playful. A children's-book narrator,
   not a coach, not a clinician, not a brand.
2. **Tired-reader rule.** The reader is in bed at 11pm. Short sentences. One idea per
   line. If a line needs re-reading, rewrite it.
3. **Celebrate, never judge.** Success is celebrated softly; failure gets sympathy and a
   fresh start. The app has no disappointed voice.
4. **Concrete farm imagery over abstraction.** Ollie guards, sheep settle, the barn light
   goes out, the phone sleeps in the other room.
5. **Honest and humble.** We count nights and minutes. We never promise sleep outcomes.

## Hard rules

- **No guilt or shame:** never "you failed", "you gave in", "broke your streak",
  "disappointed", or a sad mascot punishing the user.
- **No loss-aversion or urgency:** never "don't lose your streak!", countdowns as
  pressure, "last chance", or red-alert phrasing.
- **No addiction-loop language:** never bait a return visit ("come back to see…"),
  tease rewards, or celebrate app opens.
- **No medical claims or overpromising:** never "improves sleep", "fixes insomnia",
  "scientifically proven". Allowed: "helps you wind down", "builds a phone-away habit".
- **No productivity jargon:** never "crush", "grind", "maximize", "optimize", "streak
  goals". This is a bedtime app, not a performance tool.
- **Bedtime/sleep wording:** frame stats as nights and rest ("nights your phone slept in
  the other room"), not output ("focus minutes logged"). Evening copy should get quieter,
  not louder; save exclamation marks for the morning, and use at most one.

## Before / after examples

| Situation | Wrong | Right |
|---|---|---|
| Early-ended run | "You broke your streak!" | "Ollie kept your spot warm. Tonight's a fresh start." |
| Missed night | "You lost your 6-day streak." | "The pasture was quiet last night. Ready when you are." |
| Run completed | "MAXIMUM FOCUS ACHIEVED! 🔥" | "The phone slept in the other room. Good night's work." |
| Start CTA | "Optimize your evening" | "Send your phone to bed" |
| Phone too close | "WARNING: FAILURE IMMINENT" | "Your phone wandered back. Ollie will walk it out again." |
| Stats header | "Screen time reduced 47%" | "9 nights your phone slept in the other room" |
| Marketing | "Scientifically proven to improve sleep" | "A gentler way to wind down without your phone" |
| Empty rewards | "No rewards yet. Get started!" | "The shelf is waiting for its first treasure." |
| Notification | "You haven't started a run today!" | (Don't send this notification at all.) |

## Review procedure

1. Collect every new/changed user-visible string (including accessibility labels,
   notification text, and alert buttons).
2. Check each against the hard rules — any violation is a required change, not a nit.
3. Check tone: read it aloud as Ollie's narrator; flag anything clinical, corporate,
   hyped, or guilt-tinged.
4. Check the tired-reader rule: sentence length, one idea per line.
5. Check context: evening strings must be calm; celebration belongs to morning surfaces.
6. Output a table: string location → current → verdict (keep / revise) → suggested
   revision. Suggestions must be drop-in ready.

## Acceptance criteria

- Zero hard-rule violations ship.
- Revisions preserve meaning and fit the UI space (roughly similar length unless the
  original was too long).
- Ollie is referenced naturally, not forced into every line.
- App Store / marketing copy makes no outcome promises.
