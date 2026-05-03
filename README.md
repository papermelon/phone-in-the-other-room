# Phone in the Other Room

**Phone in the Other Room** is a hackathon-quality iOS plus Apple Watch prototype where you send Ollie the Border Collie on a Focus Run by leaving your iPhone in another room. The Watch becomes the active companion and the iPhone stays open on a leave-me-here screen.

Key line: Instead of fighting your phone, you send it to the other room and let Ollie guard your focus.

## Repository Status

This repository is an open-source iOS plus watchOS prototype. It is not an App Store-ready release, and it is not a hosted web deployment.

The code is available under the [MIT License](LICENSE). The checked-in artwork is intentionally redacted placeholder art; see [ASSET_NOTICE.md](ASSET_NOTICE.md).

## Platforms

- iOS 17+
- watchOS 10+
- SwiftUI
- WatchConnectivity
- NearbyInteraction where supported
- Local UserDefaults persistence

The project is generated with XcodeGen from `project.yml`.

Before running on your own devices, replace the placeholder bundle identifiers in `project.yml` with identifiers under your Apple Developer account.

## Run The iOS App

1. Install XcodeGen if needed.
2. Run `xcodegen generate`.
3. Open `PhoneInTheOtherRoom.xcodeproj` in Xcode.
4. Select the `PhoneInTheOtherRoom` scheme.
5. Run on an iPhone simulator or device.

## Run The Watch App

1. Open the generated Xcode project.
2. Select the `PhoneInTheOtherRoom` iPhone scheme first.
3. Choose the paired iPhone plus Apple Watch run destination.
4. Run the iPhone app; Xcode embeds and installs the Watch app from the iPhone target's **Embed Watch Content** phase.
5. Open Phone in the Other Room on Apple Watch, or select `PhoneInTheOtherRoomWatchApp` after the companion app has installed if you want to debug the Watch UI directly.

If you are installing on real devices, select the same Apple Development Team for both the iPhone target and the Watch target in Xcode. If XcodeGen is run again, recheck signing because generated project settings may overwrite manual Xcode signing choices.

## Capabilities And Plist

Required user-facing purpose string:

`NSNearbyInteractionUsageDescription`: "Ollie uses nearby-device distance to check whether your iPhone is away from your Apple Watch during a Focus Run."

Both generated targets include the `com.apple.developer.nearby-interaction` entitlement:

- `PhoneInTheOtherRoomApp/PhoneInTheOtherRoom.entitlements`
- `PhoneInTheOtherRoomWatchApp/PhoneInTheOtherRoomWatchApp.entitlements`

After running `xcodegen generate`, confirm Xcode still has a valid signing team selected for both the iPhone target and Watch target. If Xcode reports that Nearby Interaction is unavailable for the selected team/profile, fix signing before debugging distance readings.

No GPS location permission is requested. No backend, analytics, Firebase, Supabase, OpenAI key, or cloud database is used.

## Focus Mode Limitation

Every run asks, "Turn on Focus Mode for this run?" in a pop-up after the user taps Send Ollie Out. The app does not silently toggle Focus, because iOS requires Focus changes to be user-approved.

The app includes a Shortcuts/App Intent action named **Start Focus Run**. A recommended user-created Shortcut is:

1. **Start Focus Run** from Phone in the Other Room
2. **Set Focus** to Do Not Disturb
3. **Open App**: Phone in the Other Room

The App Intent prepares the selected run duration locally. When the app opens, the user still confirms the run with **Send Ollie Out**.

## Nearby Interaction Limitation

Nearby Interaction estimates device distance when supported by the hardware and session pairing. It does not identify exact rooms and should be treated as a fuzzy "near, drifting away, probably away" signal. The app uses smoothing, sustained samples, confidence labels, and friendly unsupported states.

The active run screens show the live `NINearbyObject.distance` value when the iPhone and Apple Watch have exchanged Nearby Interaction discovery tokens and the hardware/profile supports precise distance measurement. If the UI says "Waiting for distance" or "Phone distance unsupported", the app is not receiving usable UWB readings yet; check real devices, both apps open, signing, Nearby Interaction permission, and the entitlements above.

For the current prototype rule, the app ignores close-distance failure checks for the first 20 seconds of a Focus Run. After that, a fresh `NINearbyObject.distance` reading below `0.3m` ends the run early. If the planned timer completes first, the run succeeds.

## WatchConnectivity Limitation

WatchConnectivity messages are best-effort. Reachable devices use `sendMessage`; low-priority state falls back to application context. The iPhone app cannot force-open the Watch app; the Watch app must be installed and running or reachable through the paired simulator/device.

The iPhone setup screen reminds the user to open Phone in the Other Room on Apple Watch before starting. When a run starts, the iPhone schedules a local reminder notification; if the Watch app is reachable and receives the run-start message, it also schedules a local Watch notification.

## Active Foreground MVP

This prototype is an active foreground focus-session game. It estimates whether a paired iPhone is near the Apple Watch, drifting away, or probably in another room. It does not identify exact rooms, does not track GPS location, does not run as an always-on monitoring system, and does not replace Find My.

During an active iPhone run, the app disables the idle timer and resets it when the run ends.

## Rewards And Streaks

Completed runs earn Ollie-themed rewards. Early-ended runs do not grant a main reward, but may grant a consolation Muddy Paw Print. Streaks advance only on successful completed runs; early runs are encouraging and do not use harsh resets.

## Implemented

- PRD in `docs/PRD.md`
- iOS SwiftUI app target
- watchOS SwiftUI app target
- Shared models for runs, proximity, rewards, progress, events, and Watch messages
- Proximity classifier with smoothing, sustained samples, stale handling, and confidence
- Unit tests for key classifier rules
- Apple-style minute/second Focus Run duration picker
- Focus Mode pop-up prompt shown when starting each run
- Shortcuts/App Intent support for preparing a Focus Run before a user-approved Focus action
- Foreground run coordinator with placement, validation, running, warning, completion, and early-end states
- Isometric/pixel-inspired iPhone UI
- Watch glance UI with timer, status, Ping Phone, End Run, completion, and early-end screens
- WatchConnectivity ping/state plumbing with visible iPhone ping feedback
- NearbyInteraction provider with discovery token support points and distance readouts
- Local persistence for thresholds, progress, rewards, and last run
- Local iPhone reminder notification and reachable-Watch run-start notification
- Phone ping haptic/sound and Watch haptics

## Stubbed Or Hardware Dependent

- Full iPhone-to-Watch app embedding/signing may need project settings adjusted in Xcode for a production archive.
- Nearby Interaction real-device validation still needs paired-device testing on supported hardware.
- Focus activation still uses Apple Shortcuts' native Focus action; the app can prepare a run, but it cannot silently turn Focus on by itself.
- Completion/too-close notifications, Live Activities, widgets, and complications are not implemented.

## 3-Minute Demo Script

1. Open the iPhone app.
2. Show **Phone in the Other Room**.
3. Say: "This is a tiny focus game where you send your phone to the other room."
4. Choose a Focus Run duration.
5. Tap **Send Ollie Out**.
6. Answer the Focus Mode prompt.
7. Show "Put your phone in the other room."
8. Show the Watch UI: "Ollie Running" and phone-away confidence.
9. Move back toward the phone early to trigger warning on supported hardware.
10. Move away before grace expires.
11. Complete the run.
12. Show happy Ollie and the reward reveal.
13. Open Reward Shelf.
14. Optional: run again and tap End Run to show sad Ollie and gentle encouragement.

Alternative line: Find My helps when your phone is lost. Ollie helps when your phone is too close.

## Future Improvements

- Real-device Nearby Interaction polish and token exchange hardening
- In-app Shortcut setup education and richer App Intent parameter summaries
- Local completion/too-close notifications
- Live Activity and Lock Screen widget
- More Ollie animations and collar accessories
- Watch complication-style summary
- Multiple calibration profiles

## License

MIT. See [LICENSE](LICENSE). Redacted visual placeholders are documented in [ASSET_NOTICE.md](ASSET_NOTICE.md).
