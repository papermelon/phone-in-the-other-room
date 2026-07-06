# Charlie-Inspired Product Audit

## Charlie Mechanics And Design Language

Charlie uses a compact daily loop: steps feed visible star thresholds, stars feed missions and statistics, and donuts fund avatar rewards. The avatar is central, emotionally reactive, and socially comparable. Screens stay low-friction by using big numbers, short labels, simple progress bars, pixel assets, and persistent bottom navigation.

Transferable patterns:

- Daily threshold rewards: steps become silver, gold, diamond, and rainbow stars.
- Time-boxed missions: monthly and daily goals show remaining time, progress, and a concrete reward.
- Avatar state: Charlie's body state reflects recent behavior, making progress visible without opening stats.
- Cosmetic economy: Charlie uses donuts; Phone in the Other Room should use sheep as the earned farm resource and coins as the spendable cosmetic currency.
- Social comparison: friends appear as avatars, stats lines compare "me" against another person, and photos add lightweight proof.
- Statistics history: recent stars, calendar days, weekly charts, and all-time summaries make the habit legible.
- Visual style: white space, oversized pixel art, thick outlines, chunky buttons, and simple tab icons make the app feel playful rather than clinical.

Non-transferable or risky patterns:

- Weight/body language should not be copied into a screen-time app. For focus, a simple daily status line is kinder and less shame-based.
- Purchasable currency is not MVP-critical and could conflict with a calm focus-product feel; coins should start as earned-only.
- Always-on social ranking would need backend, privacy design, blocking/reporting, and careful pressure management.

## Current App Audit

Phone in the Other Room already has a strong focused loop: choose a run, send Ollie out, leave the phone behind, use Watch as the active companion, complete the run, and receive a collectible. The app's warm dark pasture palette, isometric yard, Ollie mascot, reward shelf, Watch UI, haptics, and battery-conscious Nearby Interaction windows are aligned with the product promise.

Current strengths:

- Clear brand and mascot: "Phone in the Other Room" with Ollie as the helper.
- iOS/watchOS feasibility: foreground runs, WatchConnectivity, Nearby Interaction, Shortcuts guidance, and local persistence.
- Kind failure model: warnings, grace periods, and consolation rewards avoid punitive behavior.
- Existing reward shelf and progress model provide a base for habit formation.

Feature gaps relative to Charlie:

- No daily target visible before starting a run.
- Progress is cumulative but not day-shaped, so "what should I do today?" is unclear.
- Stats are sparse: completed runs, minutes, streak, and shelf count only.
- Ollie does not reflect recent focus behavior outside the active run state.
- Social and Screen Time integrations are not present.
- Rewards are collected but cannot yet be arranged, equipped, or used for gentle personalization.

## Prioritised Roadmap

### MVP

1. Daily focus mission based on completed other-room minutes.
2. Graded focus stars at 15, 30, 60, and 120 minutes.
3. Lightweight focus stats: star counts, recent day history, and last-7-day minutes.
4. Ollie daily status based on today's focus and streak.
5. Light pixel-style Home/Farm shell with sheep and coin balances.

### V2

1. Screen Time import using Apple's FamilyControls, ManagedSettings, and DeviceActivity frameworks where entitlement and UX constraints allow it.
2. User-set daily focus goal with Apple Watch complications or widgets.
3. Reward shelf improvements: rarity filters, featured reward, and simple cosmetic equip slots.
4. Share card for a completed run or weekly focus trail, generated locally.
5. Local-only friend mock/preview mode for demoing social comparison without a backend.
6. Sheep selling and coin pricing for Ollie/room cosmetic items.

### Long Term

1. Privacy-preserving social circles with opt-in comparisons, no public leaderboards by default.
2. Rich avatar cosmetics earned through consistent focus rather than purchased currency.
3. Calendar heatmap and monthly challenges tied to lower Screen Time, not only completed runs.
4. Live Activities and Lock Screen surfaces for active focus state.
5. Multi-device reliability polish after real-device Nearby Interaction validation.

## Implemented In This Pass

- Added daily focus records to local progress.
- Added focus star tiers based on completed Focus Run minutes.
- Added an Ollie daily status that adapts the home subtitle and mascot mood.
- Organized stats into Today, Trends, and Sleep & Recovery views, with Screen Time and HealthKit values marked as pending integrations.
- Added a light pixel-style Home/Farm navigation shell inspired by the new mockups.
- Added sheep and coin balances to local progress, with completed runs earning both.
- Added a daily mission card on the home screen.
- Added a Focus Stats screen with star totals, recent history, and a last-7-day bar view.
- Added tests for daily star accumulation and legacy progress decoding.
