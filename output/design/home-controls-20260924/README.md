# Home controls and Farm choice — 24 September 2026

Local source changes:
- Home’s Edit Wind Down now opens `FocusRunSetupView`, the same full editor used by Settings. Previously Home opened the timing-only `WindDownTimingView`, omitting automatic-start and routine controls.
- Automatic Wind Down toggle, scheduling status, and protection repair link appear directly below Home’s evening timing card, using the existing settings/coordinator path.
- Slumber Party and Campfire info buttons are inside full-width cards, separate from their navigation buttons, with labelled 44-point targets.
- The exceptional Farm choice compares account and phone sheep/wool and explains that choosing one resumes automatic sync without combining progress. Both existing selection actions already reconnect sync.
- A launch-only Screenbook variant (`-screenbook-home-controls`) displays the affected controls together with isolated fixtures.

The reported automatic-start failure is not reproduced on the physical phone. Existing source includes the September 21 fix preserving due occurrences during same-account refresh. Distribution and the signed-device boundary checks remain required. The September 22 investigation records the stale September 12 server Farm and locally repaired remote date decoding; neither Farm was selected or replaced during this task.

Validation:
- `python3 scripts/validate-farm-save.py`: 83 tests passed, zero failures.
- Full generic iOS Simulator app build: passed.
- Full Xcode unit suite after the Home routing correction: 1,131 tests passed, zero failures.
- Isolated recovery probe: all 21 cases passed, including due/future automatic occurrences surviving same-account sync. See `recovery-probe.json`.
- Inspected the normal dark Home controls fixture and accessibility3 automatic-start/Campfire layout. Both info buttons were exposed separately in the accessibility tree and opened the correct sheets. Captured `home-controls.png`. Full large-text scrolling and physical VoiceOver remain unverified; the UI automation could not scroll this Simulator window.
- `git diff --check`: passed. No production actions or distribution.
