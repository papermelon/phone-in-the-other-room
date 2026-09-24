# Campfire continuity and motion — 20 September 2026

Founder-authorized implementation following the Mobbin review. This changes the common
Campfire panel reached from Home, Farm and private parties; it does not redesign the other
release tabs or the Slumber Party hub.

## Presentation

- One stable-height campsite remains through loading, empty, populated, refreshing, stale,
  signed-out and failed states. Status and retry controls sit within the same scenery; the scene can grow for long accessibility-size messages.
- The existing paper fire gains subtle native flame motion. It becomes static under Reduce
  Motion, when the app is inactive, or when the view leaves the hierarchy. Other uses of the
  fire illustration remain static by default. No new artwork or dependency is required.
- Routine refresh retains only a still-current, authorized snapshot. Expired, failed,
  account-invalid or otherwise unavailable presence is removed; the scenery remains.
  The existing account, membership, freshness and consent checks remain authoritative.
- A retry shows its loading state instead of continuing to show the previous error throughout
  the request. Empty success remains distinct from unavailable presence.
- Gathering selection remains above the Global scene while loading; channel selection and
  optional updates follow the scene. Viewing and Gathering share a row at ordinary text sizes and stack at accessibility sizes. Visibility has its own lighter row alongside refresh.
- The accessible participant list remains available in **People here**. **Reset seats** is
  under **Seating options**. Existing local seat identity, drag behavior, profile actions,
  typed session starts and running-session return routing remain intact.

## Refresh behavior

Removed the duplicate command-drain invocation immediately after the initial refresh.
Periodic reads are skipped while the selected private or Global read is already refreshing.
This does not suppress realtime invalidation or refreshes following acknowledged mutations.
The existing retry interval and terminal-error retry policy are unchanged. No network latency
improvement is claimed without a live trace.

## References

- [AllTrails loading skeleton](https://mobbin.com/screens/a6a7bb97-d19a-410e-94cc-9473cbeeb39b): preserve the space content will occupy.
- [Mimo loading illustration](https://mobbin.com/screens/96ca0f90-5f58-4b0b-adcd-0f7836b063af): illustration plus one brief status.
- [Speak loading illustration](https://mobbin.com/screens/9366c893-4599-44a9-95eb-bf352bd740f3): a focused character/status composition.

The screenshots establish composition, not competitor animation timing. Motion here uses
Counting Sheep's existing Canvas illustration.

[Native captures and validation](../../output/design/campfire-polish-20260920/README.md).
