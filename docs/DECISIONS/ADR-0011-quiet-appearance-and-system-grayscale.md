# ADR-0011: Quiet appearance and system grayscale

## Status

Accepted for the current Wind Down build.

## Decision

Counting Sheep may soften the appearance of its own active Wind Down screen with a
lower-saturation treatment. It must not attempt to change the whole iPhone display.

Apple does not provide a public API for an app to toggle system-wide Color Filters or
grayscale. Users who want that broader treatment can optionally create a personal Shortcut
automation that turns Color Filters on at Wind Down and off in the morning. The app explains
that choice in Settings and never changes the system setting without the user.

## Consequences

- The active journey remains readable and calm without relying on private APIs.
- App shielding and Live Activity remain independent of display appearance.
- Physical-device QA should verify the in-app treatment and the guidance copy, while system
  Color Filters remain user-owned and outside the app's control.
