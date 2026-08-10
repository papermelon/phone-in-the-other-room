# ADR-0011: Quiet appearance and system grayscale

## Status

Superseded, 2026-08-10. Retained as a historical record.

## Decision

The original Wind Down build experimented with a user-controlled lower-saturation
treatment for the app's active screen. That experiment was removed from the shipping
product and superseded by a canonical muted matte-black active Wind Down background.
Counting Sheep must not attempt to change the whole iPhone display.

Apple does not provide a public API for an app to toggle system-wide Color Filters or
grayscale. Users who want a broader system treatment can manage Apple's accessibility
settings themselves; that choice is outside Counting Sheep and is not presented as a
product feature.

## Consequences

- The active journey remains readable and calm through the design system's matte-black token,
  without relying on private APIs or a runtime saturation switch.
- App shielding and Live Activity remain independent of display appearance.
- The legacy `ollie.quietAppearance.enabled` default remains only in the local-reset cleanup
  registry so older installations can discard stale data; it has no runtime or UI effect.
