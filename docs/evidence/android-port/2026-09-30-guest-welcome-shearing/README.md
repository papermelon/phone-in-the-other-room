# AND-008 follow-up — guest introduction, starter/welcome and real shearing

30 September 2026. Authorized offline local implementation in the existing Android application module. This follows the preserved [AND-007](../2026-09-30-and-007/README.md) and [AND-008](../2026-09-30-and-008/README.md) evidence. Physical protection acceptance remains pending on the [single consolidated checklist](../../../plans/android-port-physical-acceptance-checklist-2026-09-30.md); it does not block independent local work.

## Source baseline and authority

HEAD: `2f3a04511eeb5bcfabdb1953dc1745f08821335c`. The checkout was already dirty, with Android/evidence/roadmap files untracked and unrelated Swift/social/backend work present. [Working-tree baseline](working-tree-before.txt), [relevant existing documentation patch](uncommitted-before.patch), [before hashes](source-hashes-before.json) and [final comparison](source-comparison.json) record that baseline. No commits, pushes, uploads, backend writes, account synchronization or Swift production edits were made. The application module, Gradle dependencies, manifest and permission scope match the baseline.

Current authorities inspected: `Shared/WelcomeReward.swift`, `SheepSearchWelcome.swift`, `FarmModels.swift`, `FarmEconomyRules.swift`, `CumulativeFarmCredit.swift`, current welcome/economy/cumulative tests, ADR-0015 as superseded by ADR-0020, and current Product Direction. Earlier Android fixtures remain historical evidence, rather than the source of new economic rules. All baseline `Shared/` and `Tests/` hashes remained unchanged. The host proof reads current production Swift; its existing adaptations only address unrelated host rendering and ActivityKit compilation.

## Implemented and integrated

- Home/Farm now provide a local guest introduction and durable welcome. No Accessibility consent is required to introduce the guest or shear wool. Protection still requires its existing consent, selection, service and repair admission.
- A fresh Farm receives Mabel once, with the current Swift deterministic starter outcome/grant identity. The grant adds no timer minutes, bonus, wool or search-meter credit. Existing Farms skip an extra starter; unknown catalog IDs and settled progress are preserved. Welcome acknowledgement changes presentation metadata only.
- Ready active sheep can be sheared from the real Farm screen. Common/uncommon/rare/legendary yields are 1/2/4/7 wool. Regrowth requires 2/3/4/5 seven-hour credit units. Sheep remain in the pasture. The presentation distinguishes ready, freshly shorn and regrowing wool.
- Shearing persists wool, remaining regrowth, last-shear time, harvest ordinal and `shear:<uppercase sheep UUID>:<ordinal>` receipt together. Stale/repeated harvest identities cannot award a new harvest after regrowth. Pending sheep, regrowing wool, unknown rarity, pre-arrival clock time and invalid ordinals reject safely.
- Early-ended Wind Down/Phone Away credit grows wool after the actual shear timestamp, with the union of Brief Access excluded. Bedtime bonuses and Morning rewards do not regrow wool. Adding the starter does not consume a cumulative-search ordinal or change the separate mode accounting.
- The same coordinator/AtomicFile authority now uses document v4 and Farm schema 2. v1/v2/v3 migrate consent, selection, occurrence/access, guest economy and v3 saved plans/receipt acknowledgements without minting historical rewards. New welcome/harvest structures must be present and valid in v4. Older-schema tags cannot hide newer fields. Incompatible/corrupt/newer documents remain preserved and write-fenced.
- Interrupted economic writes expose no optimistic grant/wool in UI. Exact pending transactions can be explicitly retried, including without Accessibility permission for guest storage recovery. Protected starts still retain all readiness gates. Restart/repeated actions keep the same permanent identities.

The optional questionnaire, protected practice/Pippin reward, Shepherd wearable gift, Shop, other Farm interactions/artwork, account and social interfaces remain follow-ups. The starter welcome is not a claim that those flows are implemented.

## Commands and outcomes

Commands ran from `android/` after `. ./env-local.sh`, using the existing workspace JDK 17/SDK 36, Gradle wrapper and offline cache. Local checks used sandbox escalation only for the existing toolchain/runtime.

```sh
python3 compatibility/run.py
./gradlew --offline :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
emulator -avd counting-sheep-isolated-api36 -no-snapshot -no-boot-anim \
  -no-audio -no-window -gpu swiftshader -port 5580
ANDROID_SERIAL=emulator-5580 ./gradlew --offline \
  :app:assembleDebug :app:testDebugUnitTest :app:lintDebug \
  :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.isolatedPrototype=true
ANDROID_SERIAL=emulator-5580 ./gradlew --offline :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.isolatedPrototype=true
ANDROID_SERIAL=emulator-5580 ./gradlew --offline :app:lintDebug :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.isolatedPrototype=true
```

[Final semantic/codec proof](parity-final.log): 195 current Swift rules/store/routing/welcome/economy tests pass. Deterministic fixture generation ran twice. Kotlin compares all semantic guest state after every step: 8 anchored timing cases, 16 credit sequences / 39 steps, 2 independent Morning sequences / 16 steps, 16 occurrence identities, current journey/Unicode rules, 2 fresh/existing starter cases and 4 rarity shear/regrowth sequences / 36 steps. Regrowth states also match current Swift. The existing 8 historical wire fixtures remain semantically compatible through current codecs; all bidirectional exchanges pass without changing their saved bytes.

[Final local validation](local-final.log): full Android debug application build, **59 JVM tests, zero failures**, and lint pass (**0 errors, 12 existing warnings**). [Final native validation](instrumentation-final.log): **9 tests, zero failures/skips** on the existing disposable API-36 `sdk_gphone` AVD. XML results and lint reports are saved alongside this document.

Native checks include real introduction/welcome/shear screen taps, persisted wool/harvest replay, disabled regrowing action at 150% text in landscape, the existing plan/start/access/early-end/early-wake/separate-receipt flow, real synthetic target interception/access/emergency controls, v1/v2 migration/recovery, corrupt/newer fences and interrupted settlement. The starter/shearing fault matrix injects failures at recovery-before-finish, before-primary, primary-before-finish and after-primary acknowledgement. Before publication, restart sees the prior state; after publication, restart sees exactly one grant/harvest. Explicit repair/restart never duplicates them. v3 migration is covered through the actual strict codec in JVM tests, preserving saved preferences/occurrence/unknown sheep.

## Repairs and review

The first implementation/proof and initial native suite passed. Review added permission-independent guest transaction retry, stricter v4 required fields and current Swift shorn/regrowing presentation. A final native assertion initially inspected an enabled text descendant rather than its disabled Compose button; [that failed run](final-validation.log) is retained. The repaired native check inspects disabled button ancestry and taps the control to prove wool/harvest counts stay unchanged. Introduction screenshots now wait for the actual screen, and landscape evidence scrolls to the sheep action rather than recording only the header. A command was initially invoked from the wrong directory before its fixture edits; it was corrected and the proof rerun. No failed check is counted as passed.

Copy review follows the repository skill: local loss/no-backup is explicit, timer credit and gifts are separate, and no sleep, placement, continuous protection or account ownership is inferred. Native Material text/styles and existing theme/touch tokens are used. Screenshot review covers portrait welcome and real saved wool, with large-text landscape controls. Physical TalkBack and OEM/night/battery checks remain pending. Screenshots: [introduction](introduction.png), [welcome](welcome.png), [saved shear](sheared-farm.png), [150% landscape sheep action](sheared-farm-large-landscape.png).

## Exercise in Android Studio and next slice

Open `android/` as the project, use JDK 17/SDK 36 and run the `app` debug configuration on an isolated emulator. On a fresh install: **Begin as a local guest → Open my Farm → scroll to Shear Mabel • 1 wool**. Wool becomes 1, Mabel is freshly shorn with 840 remaining eligible timer minutes, and another harvest is disabled. Restart preserves this state. Home's usual-plan/setup/start flows and separate Nights receipts remain available. Existing Farms receive a welcome without an extra starter.

`GuestFarmActionsTest` and `DomainParityTest` exercise growth/regrown second harvest and interruption with injected deterministic timestamps; no overnight wait or fabricated progress button is needed. Native tests require the explicit disposable-emulator opt-in above. No personal-device permissions or fixtures were used. Cleanup restores font scale/accessibility settings and stops the isolated emulator; see [cleanup](emulator-cleanup.txt).

Recommended next bounded AND-008 slice: optional protected onboarding practice and its separate once-only Pippin reward, using the same coordinator/transaction and keeping practice out of ordinary search-meter credit. Physical acceptance still gates protection claims and release readiness. No release, distribution, full solo-launch parity or verified account-owned Farm is claimed.
