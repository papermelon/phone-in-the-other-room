# Campfire character profiles — 20 September 2026

Founder direction replaces the preset public alias, coarse-time-only card, and prohibition on profile history. Use **Campfire** and **Global Campfire** consistently. The same character name and appearance belong throughout the product; no public alias picker. The founder’s later “claim your handle” GTM flow will claim this same account identity, not introduce another Campfire identity. Handle reservation/claiming is a future feature, not implemented by this change.

Saving Global visibility shares the character name/look, activities, current tasks, Wind Down routines, session state and exact times, intention, recorded history, party names, Farm inventory and Farm appearance. Anyone browsing Global Campfire, including selected party members opening the profile from their party, can see it while the person has a current shared session. The existing Off / My Slumber Party / Global choice remains the only audience control. No extra field toggles or pseudonym setup.

A visible activity/thought bubble accompanies each seated Shepherd and opens their profile. The accessible list opens the same details. Reuse the existing character and Farm renderers. No new social network, chat, matching system or tab is part of this change.

## Numbered channels

Global Campfire has **eight shared participants per numbered channel**, matching the eight meadow seats. Occupied channels keep their numbers; empty numbers can be reused. One empty channel remains available and more open as needed. There is no arbitrary fixed total channel count. The channel menu shows exact occupancy (for example, “Channel 2 · 5/8”). Wind Down/activity filters apply inside that channel.

Changing channels moves an existing shared session atomically; with no shared session, it only changes browsing. Starting in a channel that filled in the meantime automatically finds another available one. A full-channel switch is rejected without displacing anyone. Channel choices do not change the Off / party / Global audience. Expiry and termination free seats, and a near-future start reserves its seat during the allowed clock-skew window. Blocking hides that person from the viewer without freeing their seat. Server allocation serializes joins/moves to enforce eight occupants under simultaneous requests.

## Implementation contract

- Existing version-1 public receipts keep their original scope. The next Save Global accepts version 2 in the same visibility sheet; no silent expansion of earlier users' acceptance. Party-only sharing retains its existing scope. Browsing never publishes.
- The backend verifies version-2 names against the account's existing character profile. Public IDs remain separate from authentication IDs. This is identity plumbing, not a second user-facing name.
- `CampfireProfileSnapshot` contains only requested display data. Farm transactions, save envelopes, account credentials, Health and app-selection tokens are not sent. History requires matching immutable account ownership; unowned legacy/device/guest history cannot be attributed to a signed-in person.
- Profiles are scoped to the exact accepted agreement and source session. The outbox replaces older pending snapshots, fences account switches, and removes profile writes on withdrawal. Detail reads recheck live presence, account blocks, kill switch and current membership when entered from a party. Session expiry, termination or withdrawal removes access. Withdrawal clears the stored profile.
- Snapshot updates use existing foreground refresh/publication callbacks. The Farm preview renders current shared sheep, equipment and character appearance; local freeform positions and animations are not synchronized. This is a view of shared appearance, not a remote-control Farm.
- History and schedule strings carry the publisher's time-zone label. History remains recorded app outcomes; it does not prove sleep or physical phone placement. Existing seven-day/24-hour session admission rules are unchanged; historical entries in the explicitly accepted profile do not become new factual sessions or rewards.
- Resource bounds: 1 MB per snapshot, up to 5,000 entries per list and 2,048 characters per display string. Oversized or malformed snapshots are rejected, never silently truncated. Profiles load on demand rather than in every eight-person gathering page.

## Delivery status

Native source, additive SQL migration `20260920120000_campfire_profiles.sql` and matching `campfire-global` Edge changes were deployed to production on [23 September](../evidence/campfire-wardrobe-deploy-20260923/deployment.md), after the earlier alias-only Global activation. Native distribution and physical two-account acceptance remain separate. Validation is recorded in `output/design/campfire-profiles-20260920/README.md`.
