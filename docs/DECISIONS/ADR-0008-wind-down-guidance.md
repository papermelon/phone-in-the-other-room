# ADR-0008: Curated Wind Down Guidance

- Status: Accepted
- Date: 2026-08-01
- Decider: Founder
- Related: ADR-0006, ADR-0007, `docs/PRODUCT_PRINCIPLES.md`

## Context

Counting Sheep should help people build a kinder relationship with screens and the edges
of sleep, not merely shield selected apps. The old app's wellness booklet contains useful
ideas about a quieter pre-bed buffer, sleep cues, reflection, and the sleep environment,
but it also includes broad health claims, a clinical sleep questionnaire, long diaries,
and checklist mechanics that do not belong in the shipping ritual.

Clinical CBT-I is a structured, multi-component treatment usually delivered with trained
support. Counting Sheep can offer carefully reviewed educational cues inspired by that
body of work without presenting itself as CBT-I, diagnosing insomnia, or prescribing a
sleep schedule.

## Decision

Counting Sheep includes a finite, locally bundled guidance library alongside the Wind Down
ritual. Guidance may appear in four places:

1. A short example during onboarding, to explain that the app is more than an app shield.
2. One optional, stable idea on Home before Wind Down.
3. One short phase-appropriate cue during wind-down or morning quiet, including the Live
   Activity. A person may separately opt into one reviewed guidance tip per night in local
   notifications; that tip replaces an existing midpoint cue, never adds a notification.
   Overnight has no educational prompt.
4. A finite guide in More with topic grouping and visible source labels.

Guidance is optional, dismissible, and never a task, score, streak, reward condition, or
notification campaign. A consented notification tip is finite, deterministic for the
night, locally bundled, and limited to one per night. Detailed HealthKit and Screen Time
data must not automatically produce individualized sleep advice. Any future adaptive
experiment requires its own decision record.

Allowed themes include quieter light and screens before bed, regular wake-time cues,
daylight and movement during the day, a calm sleep environment, keeping the bed a sleep
cue, relaxation, and reducing pressure to force sleep. The app must not implement sleep
restriction, sleep-efficiency targets, diagnosis, medication advice, PSQI scoring, or
claims that Wind Down improves sleep.

Every item carries a source identifier. The reviewed source list lives in
`docs/SLEEP_GUIDANCE_SOURCES.md`; content must be reviewed by a qualified sleep or CBT-I
reviewer before external release.

## Consequences

- Onboarding explains Protect → Replace → Learn rather than presenting shielding as the
  whole product.
- The active run remains a status surface, not an educational feed.
- Notification tips remain a separately consented replacement for an existing cue, not a
  new engagement channel; usage-aware reminders are generic and phase-specific.
- Guidance content can be audited and updated without changing the session state machine.
- App Store copy must describe support for winding down, not treatment or sleep outcomes.
- The previous post-1.0 educational-note gate is satisfied for the current curated scope;
  adaptive coaching remains deferred.
