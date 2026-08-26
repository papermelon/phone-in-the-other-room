# ADR-0013 — Lock Screen Quiet Note

## Status

Accepted for the first widget implementation, 2026-08-06; app editor bridge repaired,
2026-08-10.

## Context

Counting Sheep already has an ActivityKit Live Activity for the temporary, phase-aware
Wind Down status. A conventional Lock Screen widget can provide a small persistent cue
below the clock, but it must remain a support for the phone-away sleep-bookend ritual,
not become a generic notes, tasks, or productivity surface.

## Decision

Ship one configurable `accessoryRectangular` WidgetKit widget named **Quiet Note** in the
existing `PhoneInTheOtherRoomLiveActivity` extension. Its single App Intent string
parameter lets a person deliberately enter a short note while configuring the widget.
The widget uses a static `.never` timeline, normalizes the text to a short Unicode-safe
value, and marks the rendered content privacy-sensitive.

The widget does not read `OfflinePurposeProfile.customText`, standard defaults, or any
other private app state. A person must explicitly enter text they want on the Lock Screen.
The existing Settings guide is also the in-app editor. It stores the normalized explicit
note in the existing App Group, reloads this widget kind after saving, and the widget opens
that editor through the `countingsheep://quiet-note` URL. The guide warns that the note may
be visible while the phone is locked.

Run phase, timer, and temporary Wind Down state remain the responsibility of the existing
Live Activity. The Quiet Note does not duplicate or modify run state.

The bridge uses the existing App Group and adds no target, cloud persistence, or new
dependency. The App Intent configuration remains as a fallback for an unedited widget;
once the in-app editor has saved a note, the explicit shared note is the canonical value
for the installed Quiet Note surface.

## Consequences

- The widget is low-maintenance and cannot guarantee real-time phase updates, which is
  appropriate because it is a persistent cue rather than a run status surface.
- Widget text is constrained by the small rectangular Lock Screen family and system
  rendering modes; short lines are recommended.
- The user controls whether and where the widget appears. Counting Sheep cannot add it
  automatically.
- Home Screen or StandBy families, Shortcuts, iCloud synchronization, and scheduled text
  rotation remain deferred until a separate product decision and privacy/entitlement
  review.
