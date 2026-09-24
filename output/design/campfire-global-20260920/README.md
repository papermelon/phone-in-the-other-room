# Ollie play feedback and Global rollout — 20 September 2026

The existing Farm caller passes `viewModel.isRunning` into `isWindDownActive`, so the established restriction covers active sessions, not only primary Wind Down. Both Fetch and Gather silently returned at the controller; the pasture menu was disabled and the Ollie profile could still request play.

The shared controller now requests a native “Play is paused” alert when either action is attempted during a session. The menu remains tappable, and profile requests still return to the pasture through the same controller. Ending the session clears the alert state and permits play; beginning a session still cancels Fetch. No reward, shielding, session or persistence behavior changed.

Validation:

- `xcodegen generate` after adding the existing controller to unit-test source membership.
- Full `xcodebuild test`, scheme PhoneInTheOtherRoom, Simulator `A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1`: **1,079 tests, zero failures**. New regression covers Fetch/Gather rejection with feedback, unchanged scene positions, play after ending, and cancellation on session start. [Log](tests.log).
- Full generic iOS Simulator `xcodebuild build`: **BUILD SUCCEEDED**. [Log](build.log).
- Native fixture `--slumber-farm-fixture --farm-state=fetch --fetch-review --fetch-active-session --fetch-ready`: [alert capture](play-paused.png). Text wraps and the native OK control is visible at the simulator's enlarged text setting. The fixture uses disposable residents and no external services.
- Standard native alert supplies accessible title/message/button semantics. Spoken VoiceOver, actual profile return navigation, menu touches and both physical-device session modes still need acceptance on the next distributed build.

[Global production evidence](../../../docs/evidence/global-campfire-deploy-20260920/deployment.md). Global activation is complete; no native distribution was performed.
