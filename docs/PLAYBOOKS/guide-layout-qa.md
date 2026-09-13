# Guide layout regression checks

The Home/Farm tour and contextual tips reserve a separate lower panel. The page above
remains scrollable and its target has a lavender outline. Advancing the tour scrolls to
the target's stable view ID. Oversized targets remain inspectable by scrolling the page.
The primer itself scrolls, including its full-width actions, when text exceeds its space.
Guide state, rewards, and acknowledgement rules are unchanged.

Validation on 6 September 2026:

- iOS + Watch simulator build succeeded.
- Full iPhone 17e simulator suite: 860 tests, zero failures.
- Isolated native component harness on the small Review iPhone SE simulator: an initially
  offscreen Phone Away target scrolls to the top of the reserved page viewport. Default
  and accessibility5 captures confirm the primer and page occupy separate regions.
- Harness source/captures are local ignored artifacts under `tmp/guide-layout/`; they use
  the production guide presentation/primer and Theme. They are not full-app acceptance.

Before distributing a new build, check the complete Home and Farm chapters, Settings and
Nights contextual tips, Back/Continue/skip/replay, VoiceOver navigation, and text-size
changes on a physical phone. At large sizes, scroll the primer to reach its actions;
scroll the page separately to inspect a target taller than the remaining viewport.
