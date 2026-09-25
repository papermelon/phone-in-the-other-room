# Campfire controls — 25 September 2026

The scene's scaled decorative background is now excluded from hit testing and the scene has a bounded content shape. Global browsing remains selectable even when the previous availability request failed. Viewing and visibility remain independent.

Campfire's 20-second read loop is removed. Entry, account/scope changes and explicit refresh still load the selected view; native pull-to-refresh awaits the actual read task, including an existing in-flight request. Shared-service invalidations/publication acknowledgements may update cached data silently. A current scene no longer switches to an Updating overlay during refresh; failed/expired observations never count as current presence.

Both start actions appear above the scene and retain the existing admission, NFC and sharing flows. Successful confirmation returns to the selected Campfire. A current local run can appear as “You · on this phone” before server acknowledgement, including with visibility Off. This does not publish anything; sharing status remains explicit. Confirmed self presence replaces the local preview. No merge, backend deployment or distribution was performed.

Validation:

- Generic iOS Simulator app build passed (`/tmp/campfire-repair-build.log`). The final-source simulator test command rebuilt the app after the last copy/accessibility corrections and passed **1,138 tests, zero failures** (`/tmp/campfire-final-source-tests.log`, result `Test-PhoneInTheOtherRoom-2026.09.25_10-26-25-+0800.xcresult`).
- `git diff --check` passed. New domain coverage rejects setup, ended and expired local seats; refreshed current snapshots retain their normal populated/empty state.
- Isolated native fixture: switched party → Global → party; opened visibility choices and selected Off without publishing; verified current party characters remain visible during a refresh. Tapped the local Shepherd and verified its sharing-status alert. Inspected standard and maximum accessibility text sizes and accessibility labels/hints. Images: `party-refreshing.png`, `local-session.png`, `maximum-text.png`.
- Pull gesture automation was unavailable (`windowNotFoundAtPosition` from the computer-use tool). Native `.refreshable` and awaited read tasks compile, but an actual pull gesture with a live backend remains unverified. Fixtures do not verify NFC/shielding admission, production visibility saves, multi-account propagation or the complete physical start-and-return flow. These checks are tracked in the 25 September backlog entry.
