# Counting Sheep Screenbook Implementation Plan

**Status:** Approved for technical spike
**Approval date:** 2026-08-11
**Product:** Counting Sheep
**Repository:** Phone in the Other Room

## 1. Purpose and approval scope

This document is the approved implementation plan for a private, local-first, code-generated Screenbook for Counting Sheep. The Screenbook will present real production SwiftUI states in a searchable, Mobbin-style microsite so the founder can:

- see screens and user journeys at a glance;
- inspect the visible copy rendered in each state;
- leave replacement copy or editorial feedback;
- approve copy revisions in batches;
- export structured review data for Codex;
- regenerate affected screenshots after code changes; and
- compare before-and-after copy and visuals.

Approval authorizes only the five-scenario technical spike defined in this document. It does not authorize later phases, a public deployment, new dependencies, new targets, changes to `project.yml`, changes to entitlements or capabilities, or release-facing debug routes. Those remain subject to the confirmation gates below.

The governing constraint is that ordinary Screenbook maintenance must require no AI or model call. Swift remains the product source of truth. The site is a generated review surface, never a second editable UI implementation.

## 2. Non-negotiable constraints

The implementation must preserve all of the following:

1. Counting Sheep's production Swift code and production models remain authoritative for UI, behavior, and copy.
2. `MVPMockData` and `Views/MVP/` remain gated and must not feed Screenbook scenarios that represent release UI.
3. Scenarios use production models with deterministic, debug-only fixtures.
4. Release behavior, the four-tab structure, and persisted-data compatibility remain unchanged.
5. No third-party dependency may be added without explicit founder approval. The technical spike uses only repository code, Apple tooling, the macOS toolchain, and the Python standard library.
6. `project.yml`, targets, signing, entitlements, capabilities, and tab structure must not change for the technical spike. If implementation establishes an exact need for one of those changes, work stops and the founder decides.
7. Screenbook routing, fixtures, launch arguments, and readiness signals are compiled only in Debug and remain inaccessible to Release builds.
8. The Screenbook is private and local for the MVP. Public or shared hosting is not part of the technical spike.
9. Building, selecting scenarios, capture, metadata generation, site generation, browsing, annotation, review export, and visual/copy drift detection are deterministic local operations with zero model calls.
10. No OpenAI API key or model runtime is required.
11. A full String Catalog migration is excluded from the technical spike. It is reconsidered only after the copy-token approach has been exercised.
12. Generated screenshots and review work products do not become normal source-control churn.
13. Existing XcodeGen and repository validation requirements remain in force.
14. The design system in `PhoneInTheOtherRoomApp/Design/Theme.swift` and `PhoneInTheOtherRoomApp/Design/PixelComponents.swift`, and the product-copy principles in `skills/product-copy-review/SKILL.md`, govern Screenbook-visible production UI.

## 3. Definitions and catalogue boundaries

The Screenbook must keep five different concepts separate.

### 3.1 SwiftUI view files

A Swift file that declares one or more `View` conformances is an implementation unit. It is not automatically a user-facing screen and does not automatically receive a gallery entry. Files such as `HomeView.swift`, `ActiveRunView.swift`, and `FarmView.swift` can each produce several materially different screen states. Conversely, a file of reusable cards can contain many `View` declarations without representing a standalone destination.

### 3.2 User-facing screens

A user-facing screen is a complete surface or destination a person recognizes in the product: an onboarding step, Home, active Wind Down, an early-ending receipt, Farm, Settings, a Watch run surface, or a Lock Screen Live Activity. Screen identity is based on the user's journey, not one-to-one correspondence with a file.

### 3.3 Screen-state scenarios

A scenario is a deterministic rendering contract for one meaningful state of a user-facing screen. It includes a stable ID, surface, journey, production root view, fixture state, environment, copy references, capture requirements, and source dependencies. One screen may have multiple scenarios for empty, configured, active, completed, error, permission-denied, accessibility, or other meaningful states.

Scenario IDs are durable external identifiers. They must not contain display copy and must not change when copy or layout changes. The format is:

```text
<surface>.<journey>.<screen-or-state>.<variant>
```

For example: `iphone.home.active-wind-down.default`.

### 3.4 Components that are not catalogued independently

Small implementation components are documented through the scenarios in which they appear. Buttons, badges, row styles, progress bars, decorative art, cards, sheets that have meaning only inside a parent screen, and helpers in `Views/Components/` do not receive standalone catalogue entries merely because they have previews. A component earns an independent entry only if it has a meaningful cross-screen state matrix that is otherwise difficult to inspect. The technical spike has no independent component catalogue.

### 3.5 System-controlled and secondary surfaces

System-rendered UI cannot be treated like an ordinary iPhone app view:

| Surface | Ownership and initial handling |
|---|---|
| iPhone app | Fully code-generated scenarios and simulator screenshots; the technical-spike surface. |
| Apple Watch | Separate target and device family; later automated Watch simulator capture where stable. |
| Live Activity / Dynamic Island / paired-Watch Smart Stack | Extension plus system host. Use extension previews and selected simulator/manual evidence; do not claim every system presentation is reproducible. |
| Notifications | Payload and app-authored copy can be catalogued. Banner, Lock Screen, Focus mode, grouping, and permission presentation are system-controlled and require simulator or manual evidence. |
| Screen Time report extension | Extension UI is app-authored but embedded in system-controlled Device Activity report presentation and entitlement-dependent. Catalogue previews plus physical-device evidence. |
| Shield configuration/action | The app supplies configuration, while the system owns the shield container and action behavior. Catalogue app-authored text/assets and retain manual physical-device screenshots. |

Each non-iPhone entry must declare its capture provenance: automated simulator, Xcode preview, payload/metadata rendering, or manual physical-device evidence. The site must never imply that a mocked system frame is an authoritative system screenshot.

## 4. Current-state inventory

### 4.1 SwiftUI and preview coverage

The repository inspection baseline on 2026-08-11 found 65 Swift files containing SwiftUI `View` declarations, 177 view declarations, and 98 `#Preview` macros across the product surfaces:

| Surface | Files containing views | View declarations | `#Preview` macros | Screenbook implication |
|---|---:|---:|---:|---|
| Main iPhone app | 56 | 167 | 84 | Strong visual exploration coverage, but previews are not a stable scenario registry. |
| Watch app | 6 | 6 | 0 | Missing preview/scenario coverage; defer to the secondary-surface phase. |
| Live Activity / Widget extension | 2 | 3 | 12 | Useful state examples exist, but system-host rendering needs special handling. |
| Screen Time report extension | 1 | 1 | 2 | Previewable app-authored content; system/entitlement context remains separate. |
| Shield extensions | 0 SwiftUI views | 0 | 0 | System configuration/action surfaces, not ordinary SwiftUI screens. |

These counts describe implementation coverage, not a count of user-facing screens. The existing `#Preview` macros are valuable fixture clues and developer conveniences, but they do not provide stable IDs, host-selectable states, deterministic simulator setup, machine-readable metadata, or capture readiness.

### 4.2 Existing reusable fixture material

Representative production-state construction already exists in previews for onboarding, Home/dashboard, setup and schedule surfaces, active-run phases, completion and early ending, Farm and its nested destinations, Settings-related surfaces, Live Activity families, and the Screen Time report. Reusable ingredients include:

- real persisted domain types such as `FocusRun`, `UserProgress`, `NightWatchPreferences`, `NightWatchPlan`, Farm models, sheep-search state, and completion receipts;
- `FocusRunViewModel` and the production session coordinator used by the iPhone root;
- deterministic model initializers that can be wrapped by debug fixture builders;
- Farm preview helpers, including `PhoneInTheOtherRoomApp/Views/FarmPreviewData.swift`, provided they construct production models and are separated from release-gated `MVPMockData`;
- Live Activity content-state examples in the widget extension; and
- stable notification template identifiers in the notification planning layer.

Existing preview data is reference material, not automatically approved Screenbook data. Some previews use the current date, current calendar/time zone, randomized identifiers or rewards, singleton services, persisted defaults, or animation/timer-driven state. Those inputs must be replaced or controlled inside the Screenbook fixture boundary.

### 4.3 Missing fixture infrastructure

The repository has no central scenario registry, capture fixture protocol, dedicated ephemeral persistence store, capture-ready handshake, simulator normalization script, scenario metadata manifest, screenshot baseline policy, review schema, static gallery generator, browser annotation store, structured export command, UI-test target, or snapshot-test library.

The principal technical gaps are:

- constructing a complete `FocusRunViewModel`/coordinator state without reading or mutating a person's normal defaults;
- fixing clock, calendar, locale, time zone, identifiers, search outcomes, rewards, notification authorization representations, and motion;
- ensuring asynchronous views declare when the intended state has actually rendered;
- mapping every visible copy occurrence to a stable review identity;
- identifying which source/asset changes invalidate which scenarios; and
- preserving review notes while regenerating generated site files.

### 4.4 Routing and dependencies

`PhoneInTheOtherRoomApp/App/PhoneInTheOtherRoomApp.swift` creates the iPhone app root and its root `FocusRunViewModel`. `PhoneInTheOtherRoomApp/App/AppRootView.swift` decides between onboarding and the main application from persisted state. `PhoneInTheOtherRoomApp/Views/HomeView.swift` is the four-tab production shell. While a Night Watch is active, Home becomes the live journey while Nights, Farm, and Settings remain reachable; completion and early-ending receipts can temporarily override the shell.

The Screenbook entry point must therefore be an early Debug-only branch at the app/root boundary, before normal persistence-based routing. It must not add a tab or a production navigation stack. Normal launches without the explicit Debug launch argument must follow the current root unchanged.

Relevant production dependencies include:

- `FocusRunViewModel` and `FocusSessionCoordinator` for authoritative run presentation;
- `PersistenceService` and `UserDefaults` for normal app data, which Screenbook fixtures must isolate;
- singleton-backed notification, Watch connectivity, HealthKit, Screen Time, NFC, Live Activity, and feedback/export services, whose side effects must be stubbed, disabled, or represented without requesting authorization;
- `Theme.swift`, `PixelComponents.swift`, and existing assets for real rendering; and
- XcodeGen source globs, which can discover added Swift files without a `project.yml` change.

### 4.5 Copy sources

Most visible iPhone copy is currently declared inline in SwiftUI `Text`, button labels, navigation titles, alerts, sheets, accessibility labels, or local computed properties. Dynamic copy also comes from formatting and domain state: dates and durations, sheep names/rarity, run phase, rewards, farm counts, notification configuration, and conditional guidance.

The notification subsystem already has 15 stable template identifiers, which are a useful precedent but do not solve general screen-copy identity. There is no String Catalog. Source line numbers are unsuitable as durable IDs because ordinary edits move them.

For Screenbook review, metadata must distinguish:

- a stable copy ID;
- the rendered value visible in the scenario;
- the Swift template or authored value when interpolation is involved;
- example parameter values;
- the production source file and enclosing symbol;
- whether the text is visible, accessibility-only, app-authored system payload, or system-owned;
- whether one token is intentionally reused in multiple scenarios; and
- a provisional source mapping versus a durable token.

### 4.6 Surfaces requiring special handling

- Camera/QR, NFC, HealthKit, Screen Time pickers, authorization prompts, and Nearby Interaction cannot be made authoritative through a normal simulator screenshot. Catalogue the app-authored pre/post states and label physical/system evidence separately.
- Keyboard, share sheet, document picker, notification permission, Family Controls picker, and other system sheets vary by OS and device. They are not technical-spike scenarios.
- Live Activities and notifications may render differently by device family, OS, Focus state, grouping, and Dynamic Island availability.
- Timers and active sessions must use a fixed clock and frozen phase, never a screenshot timed by wall clock.
- Dynamic Type, localization, right-to-left layout, color scheme, Reduce Motion, and increased-contrast variants are important later matrices. They are not multiplied across the five-scenario spike.

## 5. Recommended architecture

### 5.1 Overview

The recommended system has four boundaries:

1. A Debug-only Swift scenario registry constructs real production views and production models with deterministic, isolated fixtures.
2. A local command-line tool builds and launches the app in a dedicated simulator, selects a scenario by launch argument, waits for a run-specific readiness signal, and captures the simulator.
3. The same tool emits normalized scenario/copy metadata and generates a static, searchable HTML/CSS/JavaScript site.
4. The browser stores annotations locally and exports a versioned JSON review batch. Codex may later interpret and apply approved batches, but it is not involved in generation or browsing.

The website never constructs or edits a visual screen. It displays a screenshot generated from Swift and links review records back to stable scenario and copy IDs.

### 5.2 Debug-only scenario registry

Introduce a small iPhone-only `Screenbook` namespace behind `#if DEBUG`. The registry owns `ScreenbookScenario` descriptors with at least:

- stable `id`;
- human title and description;
- surface, journey, route, and state tags;
- fixture version;
- a deterministic production root-view factory;
- environment requirements;
- copy references;
- source and asset dependency paths;
- capture readiness policy; and
- unsupported/system-controlled notes.

The fixture layer constructs production domain values. It may add dependency-injection seams where existing singleton use prevents isolation, but production defaults and behavior must remain unchanged. Fixture data must use fixed identifiers, a fixed Gregorian calendar, `Asia/Singapore`, a fixed date, fixed sheep/reward outcomes, and explicitly seeded collections. It must not call `MVPMockData`, request permissions, schedule notifications, start ActivityKit, write normal `ollie.*` defaults, contact Supabase, or communicate with a Watch.

Selection uses explicit Debug launch arguments:

```text
-screenbook-scenario <stable-id>
-screenbook-run-id <unique-run-id>
```

Unknown or malformed scenario IDs display a clearly identifiable Debug error surface, write a structured failure signal, and cause the capture tool to fail. In non-Debug builds, the registry, argument names, fixture code, root route, and readiness writer are not compiled.

The registry must be the canonical source of scenario metadata. The local tool obtains a machine-readable manifest from the built Debug app through a special registry-export launch operation or app-container artifact; it must not maintain a manually duplicated list of scenario IDs in Python.

### 5.3 Capture readiness and simulator mechanism

The local tool uses `xcodebuild` and `xcrun simctl`; no UI-test target is required for the spike.

For each capture it will:

1. verify the requested Xcode, runtime, simulator, command-line tools, and output paths;
2. build the Debug app once unless the caller supplies a valid existing build;
3. boot a dedicated named simulator or an explicitly selected device;
4. normalize portrait orientation, appearance, locale, language, time zone, content size, status-bar time/network/battery, and motion settings;
5. install the build;
6. remove only the prior Screenbook readiness artifact from the resolved app container;
7. launch with scenario ID and unique run ID;
8. poll the app container for a matching structured readiness file;
9. capture with `simctl io ... screenshot` only after the scenario reports stable rendering;
10. validate image existence and dimensions, generate hashes, and stage metadata; and
11. atomically replace that scenario's current artifacts only after every step succeeds.

Readiness must be explicit, not a fixed blind sleep. The root reports ready after the scenario's synchronous state is installed and the intended view has completed its declared render settling. Animated/timer-driven behavior is frozen in the fixture. A bounded settling interval of main-run-loop turns may be part of the readiness implementation, but it is subordinate to the run-ID handshake.

The canonical technical-spike capture profile is:

```text
Device: iPhone 17 simulator
Runtime: iOS 26.5
Orientation: portrait
Language: English
Locale: en_SG
Time zone: Asia/Singapore
Text size: standard/large default
Appearance: scenario-declared, otherwise light
Reduce Motion: enabled
Status bar: fixed time, full network, fixed battery
```

These values are an approved reproducibility profile, not a claim that other devices do not matter. Later phases may add named profiles rather than silently changing the canonical one.

### 5.4 Copy identity strategy

The spike adds a lightweight production-safe `AppCopyToken` value type, not a localization framework. A token has a stable semantic ID and an authored Swift value or formatting closure. Production views render the token's value; Screenbook metadata refers to the same ID. Token IDs use semantic namespaces such as:

```text
iphone.onboarding.welcome.title
iphone.home.configured.start-button
iphone.active.wind-down.phase-title
iphone.early-end.receipt-title
iphone.farm.flock-summary
```

The type may compile in Release because production views use it, but all Screenbook enumeration and source metadata remain Debug-only. Token declarations should stay close to their production domain or call site, with one shared primitive rather than a second editable copy database.

The technical spike tokenizes only the review-critical visible copy needed to prove the five scenarios. Any visible string not yet tokenized must still appear in the screenshot and may be recorded with a clearly marked provisional source anchor of file plus enclosing symbol. Provisional IDs cannot be approved for automated application until converted to stable tokens. Source line numbers can be diagnostic metadata but never identity.

Dynamic tokens export both the authored template/meaning and the concrete rendered value for that scenario. The site must not invite a founder to replace interpolated values without showing which parts are parameters. Identical rendered text with different editorial purposes gets different IDs; intentionally shared text reuses one ID and lists all occurrences.

### 5.5 Scenario metadata schema

The generated manifest is versioned and deterministic. A scenario record is conceptually:

```json
{
  "schemaVersion": 1,
  "id": "iphone.home.configured.default",
  "title": "Configured Home",
  "surface": "iphone",
  "journey": "night-watch",
  "route": "home",
  "state": "configured",
  "fixtureVersion": 1,
  "captureProfile": "iphone17-ios26.5-enSG-standard",
  "sourceRevision": "optional-git-sha-or-working-tree",
  "screenshot": {
    "path": "screens/iphone.home.configured.default.png",
    "width": 1206,
    "height": 2622,
    "sha256": "...",
    "pixelHash": "..."
  },
  "copy": [
    {
      "id": "iphone.home.configured.start-button",
      "rendered": "Start Quiet Time",
      "authored": "Start Quiet Time",
      "kind": "visible",
      "source": {
        "file": "PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift",
        "symbol": "PixelHomeDashboard"
      },
      "status": "stable"
    }
  ],
  "dependencies": [
    "PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift",
    "PhoneInTheOtherRoomApp/Design/Theme.swift"
  ],
  "captureProvenance": "automated-simulator",
  "warnings": []
}
```

Actual image dimensions come from the captured canonical simulator and are not hard-coded to this illustrative record. Metadata fields are sorted or emitted in a stable order, dates are excluded unless semantically required, and volatile build paths do not enter hashes.

### 5.6 Copy-review schema

Founder annotations export as a separate versioned JSON document. The export never changes Swift. It contains:

```json
{
  "schemaVersion": 1,
  "screenbookManifestHash": "...",
  "createdAt": "2026-08-11T00:00:00Z",
  "reviewer": "founder",
  "batchTitle": "Onboarding and first-night copy",
  "items": [
    {
      "reviewId": "...",
      "scenarioId": "iphone.onboarding.welcome.default",
      "copyId": "iphone.onboarding.welcome.title",
      "sourceRendered": "...",
      "sourceAuthored": "...",
      "proposedReplacement": "...",
      "editorialNote": "...",
      "decision": "approved",
      "sourceManifestHash": "..."
    }
  ]
}
```

Supported decisions are `open`, `approved`, `rejected`, and `needs-discussion`. Approval applies to the proposal in the export, not automatically to source code. Each item carries the original value and manifest hash so stale proposals can be detected before application. Screen-level notes may omit `copyId`; copy replacement items require a stable copy ID.

The deterministic tool validates imports/exports against the schema, rejects duplicate review IDs or unknown decisions, and reports unknown/stale scenario and copy IDs without dropping data.

### 5.7 Static website

The website is generated vanilla HTML, CSS, and JavaScript served by Python's local HTTP server through the Screenbook CLI. It has no package manager, bundler, analytics, remote fonts, CDN, network API, or model integration.

The MVP site provides:

- free-text search across scenario ID, title, journey, state, tags, visible copy, and notes;
- filters for surface, journey, route/state, review status, change status, and warnings;
- a gallery card with screenshot, title, stable ID, and change badges;
- a detail view with the full screenshot, metadata, source links as text paths, all visible copy records, and capture provenance;
- proposed-copy and editorial-note inputs;
- batch selection and decision controls;
- review JSON import/export;
- current-versus-baseline copy comparison;
- current-versus-baseline screenshot toggle or side-by-side comparison; and
- clear labels for provisional copy mappings and system/manual evidence.

The initial site is usable at desktop founder-review widths and remains readable at narrow widths. It need not be a production mobile website.

### 5.8 Local annotation persistence

Annotations persist in browser storage under a versioned key scoped to a stable local origin and scenario/copy IDs. The CLI serves on a stable configurable localhost port so regeneration does not change the origin. Generated HTML never contains the mutable annotations.

Because browser storage is not a backup, the site supports explicit JSON export and import from the technical spike. Before clearing browser/site data, the founder exports a review batch. Later hardening may add File System Access API support where available, but portable JSON download/import remains the baseline.

### 5.9 Generated-artifact policy

Version-controlled inputs:

- Debug scenario/fixture/copy-token source;
- local capture/generation scripts;
- HTML/CSS/JavaScript templates;
- JSON schemas;
- Screenbook playbook and durable design decisions; and
- small test fixtures for the generator, not product screenshots.

Locally generated and ignored outputs:

- built app products and DerivedData;
- current screenshots;
- accepted local visual baselines;
- diff images and manifests tied to a working tree;
- generated site output;
- imported/exported review work files unless the founder explicitly chooses a review batch for version control; and
- capture logs.

Use `tmp/screenbook/` for generated outputs if the repository's ignore policy covers `tmp/`. If it does not, add only the narrow ignore rule required. Never check hundreds of generated PNGs into the normal product history by default.

### 5.10 Refresh modes

The CLI contract should support:

```text
python3 scripts/screenbook/screenbook.py doctor
python3 scripts/screenbook/screenbook.py list
python3 scripts/screenbook/screenbook.py capture --scenario <id>
python3 scripts/screenbook/screenbook.py capture --changed
python3 scripts/screenbook/screenbook.py capture --all
python3 scripts/screenbook/screenbook.py build-site
python3 scripts/screenbook/screenbook.py serve
python3 scripts/screenbook/screenbook.py verify
python3 scripts/screenbook/screenbook.py accept-baseline --scenario <id>
```

- **Single scenario:** builds once if necessary, captures one ID, updates only its manifest/site record, and preserves every other scenario artifact and annotation.
- **Changed:** compares registered dependency paths, fixture versions, capture profile, and prior fingerprints; captures the affected set. If dependency mapping is incomplete or a global dependency changes, it fails safe to a broader capture.
- **All:** captures every registered scenario and produces a complete manifest.
- **Site-only:** rebuilds from existing valid artifacts without booting a simulator.
- **Baseline acceptance:** copies selected current artifacts into the local baseline set and records their hashes. This is deterministic and distinct from approving editorial copy.

The command must print the exact scenario set before capture and a final per-scenario status summary.

### 5.11 Drift and change detection

Each scenario fingerprint combines:

- scenario ID and fixture version;
- canonical capture-profile version;
- relevant scenario descriptor and fixture source hashes;
- explicitly registered production view, model, design-token, formatter, and asset dependencies; and
- tool/schema version.

The generated current manifest is compared with the prior current manifest and optional accepted baseline. The tool detects:

- added, removed, or renamed scenarios;
- changed screenshot pixels or dimensions;
- changed rendered/authored copy under a stable copy ID;
- a copy ID whose source anchor disappeared;
- duplicate copy or scenario IDs;
- a source dependency changed without recapture;
- stale review items whose source manifest/value no longer matches; and
- missing/manual evidence.

The technical spike may use normalized PNG/pixel hashes and side-by-side comparison. Production hardening can add an Apple-framework-based pixel-diff helper with thresholds and heat maps, still without a third-party snapshot library. A screenshot difference is reported, not automatically declared a regression.

### 5.12 Failure handling

- `doctor` fails before capture if Xcode, XcodeGen, runtime, simulator, Python, free space, or required commands are missing.
- Every run uses a unique run ID and an explicit bounded readiness timeout.
- A timeout records the launch result, simulator state, app container status, and app logs. It never saves a screenshot under the requested scenario ID unless readiness matched.
- Output is staged per scenario and atomically promoted. A failed refresh leaves the last valid current artifact intact but visibly records the failure in the run summary.
- Unknown IDs, duplicate IDs, schema failures, image dimension mismatches, and missing copy/source mappings cause a nonzero exit.
- Commands target resolved, validated Screenbook directories and must not use broad destructive paths.
- Simulator retries are bounded. One retry may reboot the dedicated simulator; repeated failure stops and reports rather than looping.
- Site generation tolerates a deliberately marked manual/system-controlled entry but not a silently missing automated screenshot.

### 5.13 Privacy and release isolation

Fixtures contain invented local data only: no real schedules, Health samples, selected-app tokens, feedback, identifiers, Supabase data, or notification content from a person's installation. The capture tool does not use a founder's daily simulator unless explicitly selected; the normal path uses a dedicated Screenbook simulator.

All scenario routing and fixture code is enclosed in `#if DEBUG`. The Release root contains no Screenbook branch. Release validation includes a Release build and source/binary checks for the launch-argument marker and registry symbols. A normal Debug launch without the argument behaves normally. The local server binds to `127.0.0.1`, opens no tunnel, loads no remote resources, and performs no telemetry.

## 6. Why this architecture fits the repository

The launch-argument Debug registry is the smallest mechanism that renders the real app in a simulator while preserving a host-selectable, deterministic contract. It fits the existing one-root-view SwiftUI architecture, needs no target or dependency, works with XcodeGen path globs, and can be isolated before normal persisted routing. A Python-standard-library generator is inspectable and available on the development machine. `simctl` captures the actual simulator instead of a reimplemented website representation.

This design also keeps responsibilities clear: Swift declares truth, the capture tool records it, the site reviews it, and a review export proposes changes. Codex is optional at the point where human language judgment and safe multi-file editing are valuable.

## 7. Alternatives considered

### 7.1 Batch-rendering Xcode previews

Previews are useful for development and already cover many states, but they are not a durable automation API. They lack stable external IDs, consistent simulator chrome, reliable host-side batch export, release-isolation testing, searchable metadata, and browser review persistence. Preview fixtures also currently include nondeterministic state. Reuse their model-construction ideas, not Preview as the primary capture engine.

### 7.2 Launch-argument scenario routing

This is the recommended selection mechanism. Its risk is debug routing leaking or growing into a parallel app. Contain it at the earliest app root, compile it out of Release, keep scenarios flat and declarative, and test a normal no-argument launch.

### 7.3 UI tests

An XCUITest target could navigate release flows and capture screenshots, but the project has no UI-test target. Adding one likely requires `project.yml` and target changes, triggering founder confirmation. UI navigation is slower and more fragile for deep time-dependent states, permissions, and persisted setup. A later smoke journey may use UI tests if the founder approves a target, but they are not needed to prove the Screenbook architecture.

### 7.4 Snapshot-test libraries

Snapshot libraries offer image assertions and diff tooling, but they add a dependency and often tie baselines to test bundles/source control. The Screenbook needs a review catalogue more than a unit-test assertion framework. Native hashing/diffing and human visual review are sufficient initially. Reconsider only if maintenance data shows the local diff tool is inadequate and the founder explicitly approves a package.

### 7.5 Figma export

Figma is valuable for design exploration but would create or encourage a second editable visual source of truth, require external service/file coordination, and not inherently render actual production states. It is out of scope for the Screenbook MVP. A later one-way reference export may be considered, never authoritative round-trip editing.

### 7.6 String Catalog migration

A String Catalog could provide identifiers and localization infrastructure, but migrating current inline and dynamic copy is a broad product-wide rewrite with regression and scope risk. The spike only needs durable editorial identities for five scenarios. `AppCopyToken` proves that contract at low cost. Reassess a catalog once localization is planned or token coverage becomes expensive; do not let Screenbook bootstrap a localization migration accidentally.

### 7.7 Direct code editing from the website

Rejected. A browser cannot safely understand Swift syntax, reuse, dynamic formatting, validation, or source conflicts. It would turn generated metadata into an editor and bypass review. The site exports proposals with source hashes; Codex or a developer applies approved batches in the repository, runs the copy-review skill and validations, and regenerates affected scenarios.

## 8. Phased implementation

Each phase is independently stoppable. A phase begins only after its own gate is satisfied and ends when its acceptance criteria are met; work does not spill into the next phase to compensate for an incomplete acceptance criterion.

## Phase 1 — Technical spike

### Scope

Prove the complete local pipeline with exactly five representative iPhone scenarios:

1. `iphone.onboarding.welcome.default` — the production welcome step inside the onboarding visual context;
2. `iphone.home.configured.default` — configured Home with a saved upcoming Quiet Time and stable Farm/progress summary;
3. `iphone.home.active-wind-down.default` — Home's production live journey frozen during active Wind Down;
4. `iphone.home.early-end.default` — the production early-ending state/receipt with no sheep-search advancement; and
5. `iphone.farm.populated.default` — the production Farm with a deterministic populated flock and stable economy state.

The spike proves stable IDs, deterministic fixtures, local build and automated simulator capture, explicit readiness, registry-derived metadata, the lightweight copy-ID path, searchable gallery, annotations/proposed copy, review import/export, single-scenario refresh, local baseline/current comparison, drift reporting, and zero-model regeneration.

It does not catalogue every onboarding step, Home variant, tab, sheet, component, Dynamic Type size, appearance, localization, Watch surface, Live Activity, notification, report extension, or shield. It does not apply a copy batch to Swift. It does not add hosting.

### Exact likely files to add

- `PhoneInTheOtherRoomApp/Screenbook/ScreenbookScenario.swift`
- `PhoneInTheOtherRoomApp/Screenbook/ScreenbookScenarioRegistry.swift`
- `PhoneInTheOtherRoomApp/Screenbook/ScreenbookFixtures.swift`
- `PhoneInTheOtherRoomApp/Screenbook/ScreenbookRootView.swift`
- `PhoneInTheOtherRoomApp/Screenbook/ScreenbookCaptureReadiness.swift`
- `PhoneInTheOtherRoomApp/Copy/AppCopyToken.swift`
- `scripts/screenbook/screenbook.py`
- `scripts/screenbook/site/index.html`
- `scripts/screenbook/site/screenbook.css`
- `scripts/screenbook/site/screenbook.js`
- `scripts/screenbook/schema/scenario-manifest.schema.json`
- `scripts/screenbook/schema/copy-review.schema.json`
- `scripts/screenbook/tests/` with small deterministic generator/schema fixtures
- `docs/PLAYBOOKS/screenbook.md`

### Exact likely files to modify

- `PhoneInTheOtherRoomApp/App/PhoneInTheOtherRoomApp.swift` and/or `PhoneInTheOtherRoomApp/App/AppRootView.swift` for the one early `#if DEBUG` route;
- the minimal relevant production copy call sites in:
  - `PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingWelcomeStepView.swift`;
  - `PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift` or the actual configured-Home call site established during implementation;
  - `PhoneInTheOtherRoomApp/Views/ActiveRunView.swift` and its production journey components only where the rendered copy is owned;
  - `PhoneInTheOtherRoomApp/Views/EarlyEndView.swift`; and
  - `PhoneInTheOtherRoomApp/Views/FarmView.swift` and only the production child owning spike-visible review copy;
- dependency-injection initializers in `FocusRunViewModel`, `FocusSessionCoordinator`, or `PersistenceService` only if required to prevent fixture side effects, with unchanged production defaults;
- `.gitignore` only if a narrow `tmp/screenbook/` ignore rule is not already effective; and
- `PhoneInTheOtherRoom.xcodeproj/project.pbxproj` only as XcodeGen-generated output if repository policy produces a change after adding globbed files—never by hand.

No other source file should change merely to increase coverage. Implementation must inspect actual copy ownership before editing the listed call sites and report any substitution.

### Dependencies

- Existing Xcode/XcodeGen project and iOS app target;
- available iOS 26.5 iPhone 17 simulator, or founder-approved update to the named canonical profile if that runtime disappears;
- Python 3 standard library;
- `xcodebuild`, `xcrun simctl`, `sips`, `shasum`, and `jq` where present (`jq` is convenience only; the Python tool remains authoritative);
- existing production design assets and models.

No new SPM, npm, pip, CocoaPods, target, capability, or entitlement dependency.

### Validation commands

```bash
xcodegen generate

xcodebuild build \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoom \
  -destination 'generic/platform=iOS Simulator' | tail -20

xcodebuild test \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoom \
  -destination 'platform=iOS Simulator,name=iPhone 17' | tail -30

xcodebuild build \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoom \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' | tail -20

python3 scripts/screenbook/screenbook.py doctor
python3 scripts/screenbook/screenbook.py list
python3 scripts/screenbook/screenbook.py capture --all
python3 scripts/screenbook/screenbook.py verify
python3 -m unittest discover scripts/screenbook/tests
```

Also run `docs/PLAYBOOKS/pre-merge-review.md`, inspect the Release product/source for Screenbook route markers, and verify a normal Debug launch without arguments follows the ordinary app root.

### Visual QA

- Compare each captured state directly with an interactive simulator launch of the same scenario.
- Confirm status bar, safe areas, fonts, assets, tab selection, sheet/receipt layering, and scroll position are intentional.
- Capture each scenario twice from the same build/profile and confirm normalized dimensions and pixel hash are stable; investigate any difference rather than immediately adding tolerance.
- Intentionally change one spike copy value and one visible style value on a disposable local test, confirm copy and visual drift are detected, then revert those disposable test edits.
- Confirm side-by-side/current-baseline browsing makes the difference obvious.
- Review all five screens against `PRODUCT_PRINCIPLES.md` and the product-copy-review skill; the spike may expose existing issues but does not silently rewrite them.

### Acceptance criteria

- The registry lists exactly the five approved IDs and rejects an unknown ID.
- Every scenario renders a real production screen/root with production models and deterministic debug-only state.
- Repeated capture from the same build/profile is stable after normalization.
- A single command captures all five without manual simulator interaction or any model/API call.
- The site is searchable by title, ID, state/tag, and visible copy.
- Every detail page shows provenance, source dependencies, fixture/profile data, copy records, and warnings.
- Stable copy IDs are demonstrated for review-critical copy on all five scenarios; any remaining mapping is explicitly provisional.
- Founder notes and proposed replacements survive site regeneration in the same browser.
- A review batch exports, validates, reimports, and preserves decisions without modifying Swift.
- `capture --scenario iphone.farm.populated.default` changes no other scenario screenshot, metadata record, baseline, or annotation.
- Current/baseline visual and copy changes are detected and viewable.
- Failed or timed-out capture cannot overwrite a valid artifact or mislabel a screenshot.
- Normal Debug launch and Release build behavior are unchanged; release isolation checks pass.
- No `project.yml`, target, entitlement, signing, capability, tab, dependency, or hosting change is required.
- Standard build and unit tests pass.

### Stopping condition

Stop Phase 1 as soon as the five-scenario vertical slice satisfies all acceptance criteria and the founder can complete one local annotation/export review. Do not add a sixth scenario as polish. If deterministic isolation requires a target, entitlement, `project.yml`, package, persisted-format, or release-routing change, stop before making it and present the exact need.

### Rollback

Remove the Debug Screenbook folder, copy-token changes (restoring the original Swift literals), root Debug branch, scripts/templates/schemas/playbook, and narrow ignore rule. Regenerate with XcodeGen if required and rerun build/tests. Generated `tmp/screenbook/` artifacts are disposable and can be moved to Trash. No persisted user migration is needed because fixtures never use production storage.

### Founder-confirmation gates

The technical spike is approved as written. New confirmation is required before:

- touching `project.yml` or adding/changing a target;
- changing an entitlement, signing setting, capability, App Group, or bundle ID;
- adding a third-party dependency;
- changing release routing, tabs, or persistence format;
- using `MVPMockData`/gated MVP UI as production catalogue truth;
- capturing or storing real personal data; or
- adding any remote service or hosting.

## Phase 2 — Production hardening

### Scope

Turn the proven pipeline into durable local tooling: modularize the CLI, add unit/integration fixtures, strengthen process/log handling, introduce native pixel comparison where useful, version migrations for manifests/reviews, validate stale annotations, document simulator recovery, and add a reliable changed-scenario dependency audit.

### Exact likely files to add or modify

- split `scripts/screenbook/screenbook.py` into focused modules under `scripts/screenbook/lib/` while preserving the CLI;
- expand `scripts/screenbook/tests/` with manifest, review, fingerprint, failure, and atomic-write tests;
- optionally add `scripts/screenbook/ImageDiff.swift` using Apple image frameworks for pixel counts/heat maps;
- harden files in `PhoneInTheOtherRoomApp/Screenbook/` without expanding catalogue scope;
- revise schemas under `scripts/screenbook/schema/` through explicit versioning;
- expand `docs/PLAYBOOKS/screenbook.md`; and
- modify `.gitignore` only if hardening introduces a new narrow generated path.

No production view should change in this phase except a demonstrated isolation defect.

### Dependencies

Phase 1 accepted; no new dependency. Native Swift/AppKit/CoreGraphics may be used by a host-side diff helper.

### Validation commands

Run all Phase 1 commands plus:

```bash
python3 scripts/screenbook/screenbook.py capture --changed
python3 scripts/screenbook/screenbook.py build-site
python3 scripts/screenbook/screenbook.py verify --strict
python3 -m unittest discover scripts/screenbook/tests
```

Exercise simulated readiness timeout, malformed manifest, stale review import, duplicate ID, insufficient disk space, missing simulator, and interrupted capture.

### Visual QA

Verify diff counts and any heat map against known one-pixel, text-only, layout, and dimension changes. Confirm tolerance does not hide material copy/layout changes. Test current/baseline selection and error labels in the gallery.

### Acceptance criteria

- CLI modules and schemas have deterministic automated tests.
- Interrupted/failed capture preserves the last valid site and artifacts.
- Stale review data is retained but clearly blocked from blind application.
- Dependency/fingerprint explanation names why each changed scenario was selected.
- Pixel comparison is deterministic on the canonical profile.
- The playbook lets a developer recover a wedged simulator without deleting unrelated devices/data.
- Phase 1 acceptance continues to pass.

### Stopping condition

Stop when the local tool is trustworthy enough to expand catalogue entries without changing its architecture. Do not add product scenarios during hardening except tiny test fixtures.

### Rollback

Return to the Phase 1 monolithic CLI/schema version and remove only hardening helpers. Existing Phase 1 manifests/reviews must remain importable or have a documented deterministic downgrade/export route.

### Founder-confirmation gates

Confirm before adopting any package, CI service, dedicated target, repository-wide baseline check-in, or changed canonical device/OS profile. Pure local refactoring under the existing constraints needs no new approval.

## Phase 3 — iPhone catalogue expansion

### Scope

Inventory user journeys and expand from five scenarios to intentional iPhone coverage. Add meaningful onboarding steps, unconfigured/configured Home variants, run phases, schedule/setup states, completion and early-end variants, Nights/history/insights, Farm/Barn/Trail/Shop/customization, and Settings/notification/feedback/export states. Add selected dark-mode and Dynamic Type profiles after base-state coverage.

Do not create one entry per Swift `View`. Use a catalogue matrix of user-facing screen × meaningful state × approved capture profile. Components remain represented inside screens unless independently reviewable.

### Exact likely files to add or modify

- `PhoneInTheOtherRoomApp/Screenbook/ScreenbookScenarioRegistry.swift`;
- split fixture files under `PhoneInTheOtherRoomApp/Screenbook/Fixtures/` by journey when the existing file approaches repository size limits;
- production copy call sites converted incrementally to `AppCopyToken` where review requires stable identity;
- production initializers only where a scenario exposes a genuine testability/isolation need;
- `scripts/screenbook/site/` templates for journey navigation/profile filters if needed;
- `docs/PLAYBOOKS/screenbook.md` catalogue matrix and scenario-authoring checklist; and
- tests/metadata fixtures for added profiles.

Likely production view families are `Views/Onboarding/`, `HomeView.swift`, `PixelHomeDashboard.swift`, `FocusRunSetupView.swift`, `ActiveRunView.swift`, `CompletionView.swift`, `EarlyEndView.swift`, `MonthlyNightsView.swift`, `FocusStatsView.swift` and its split sections, `FarmView.swift`, `BarnView.swift`, `TrailBoardView.swift`, `TrailNotesArchiveView.swift`, `FarmShopView.swift`, `ShepherdCustomizationView.swift`, `MoreView.swift`, and notification/settings views. Actual edits must follow the file that owns the copy/state at implementation time.

### Dependencies

Phase 2 accepted; a founder-approved catalogue matrix and priority order. No new package or target.

### Validation commands

Run standard build/tests, generator tests, `capture --changed`, `verify --strict`, and a scheduled `capture --all`. Add registry checks that every ID is unique and every automated iPhone scenario has a current artifact for the canonical profile.

### Visual QA

- Founder reviews each journey as a sequence, not an alphabetical pile.
- Check empty, loading/permission, happy, and factual failure states where meaningful.
- Validate text clipping at the selected Dynamic Type sizes.
- Confirm dark bedtime screens remain comfortable and warm.
- Confirm the site labels sheets/overlays and their parent route.

### Acceptance criteria

- An approved catalogue matrix maps screens to scenarios and explicitly lists excluded components/system surfaces.
- All release-reachable iPhone journey screens have at least one representative scenario or a documented reason for exclusion.
- High-risk conditional states have deterministic coverage.
- Each scenario has stable ID, fixture version, provenance, dependencies, copy metadata, and owner/journey tags.
- No scenario uses gated MVP mock data or production personal storage.
- Full refresh and changed refresh remain reliable at expanded scale.
- Dynamic Type gaps discovered by capture are recorded and fixed in normal product work rather than hidden.

### Stopping condition

Stop when the approved iPhone matrix is complete. Do not proceed automatically into every permutation, localization, Watch, or system surface.

### Rollback

Remove newly registered scenarios and their fixtures/tokens in journey-sized batches. Regenerate the site; earlier scenario IDs and review exports remain valid. Roll back production copy-token conversions by restoring equivalent literals only if the founder abandons durable copy IDs.

### Founder-confirmation gates

Founder approves the scenario matrix and any new capture profiles. Stop for any change to release navigation, tabs, persisted models, `project.yml`, dependencies, entitlements, or product behavior discovered while making a state renderable.

## Phase 4 — Copy workflow

### Scope

Operationalize editorial review: complete durable IDs for reviewable iPhone copy, add batch grouping and conflict checks, document review/application responsibilities, and exercise an approved batch from export through Codex-applied Swift edits and affected-scenario regeneration.

The site remains proposal-only. Applying a batch is a repository task that invokes judgment, product-copy guidance, normal code review, and validation.

### Exact likely files to add or modify

- `PhoneInTheOtherRoomApp/Copy/AppCopyToken.swift` and production call sites selected by an approved review batch;
- `scripts/screenbook/schema/copy-review.schema.json` for additive versioned fields only;
- `scripts/screenbook/site/screenbook.js` and CSS/HTML for batch approval and conflict presentation;
- `scripts/screenbook/` validators for stale values, duplicated proposals, and affected-scenario calculation;
- `docs/PLAYBOOKS/screenbook-copy-review.md`; and
- durable founder style guidance in the already canonical product-copy skill or product principles only when the founder explicitly approves a generalizable rule.

Do not update `AGENTS.md` or canonical product guidance merely because one batch contains a one-off preference.

### Dependencies

Phase 3 coverage for the copy being reviewed; founder-approved review JSON; `skills/product-copy-review/SKILL.md`; no runtime model or API dependency.

### Validation commands

Validate the review JSON, run a dry-run mapping report, inspect every source/current-value match, apply only approved non-stale items, then run standard build/tests, `capture --changed`, `verify --strict`, and the product-copy-review workflow. Search for old copy where the batch expects removal while respecting intentional reuse.

### Visual QA

Compare before/after screenshots and copy records for every affected scenario. Check wrapping, truncation, hierarchy, warmth, factual accuracy, accessibility labels where applicable, and no medical or misleading claims. Founder gives final approval to the rendered result, not just the JSON proposal.

### Acceptance criteria

- The export-to-application workflow detects stale source text before editing.
- Only `approved` stable-ID items are eligible for application.
- One approved batch is applied without manual re-entry, with an auditable mapping from review item to Swift source.
- Affected scenarios are recaptured without recapturing unrelated scenarios.
- Before/after copy and visuals are retained locally and reviewable.
- General founder style preferences are separated from one-off screen edits and, when approved as durable, added once to canonical guidance.
- The site still cannot write Swift.

### Stopping condition

Stop after one real batch completes end-to-end and the founder approves the rendered result. Further batches become routine operations, not a new architecture phase.

### Rollback

Revert the applied Swift copy changes as one review batch, recapture affected scenarios, and retain the review export with a rejected/reverted outcome. Schema/site changes can revert independently if earlier exports remain readable.

### Founder-confirmation gates

Founder approves each batch's final wording. Explicit confirmation is required before turning a recurring preference into canonical repository guidance, beginning localization/String Catalog migration, or changing product behavior under the guise of copy.

## Phase 5 — Secondary Apple surfaces

### Scope

Add separate, provenance-aware catalogues for Watch, Live Activity/widget families, notification payloads and selected system presentations, Screen Time report extension, and shield configuration/action. Treat each surface as its own capture adapter and matrix; do not force them through the iPhone scenario root.

Recommended order:

1. Watch production views with deterministic `WatchRunViewModel` fixtures and Watch simulator capture;
2. Live Activity/widget preview states plus selected supported simulator system captures;
3. notification app-authored templates/payloads, with manual/system screenshots clearly labeled;
4. Screen Time report extension preview states plus physical-device evidence; and
5. shield app-authored configuration plus physical-device system evidence.

### Exact likely files to add or modify

- new Debug fixture/registry files inside `PhoneInTheOtherRoomWatchApp/` and minimal Debug route changes in its app root;
- existing Watch production views only for durable copy IDs/testability seams;
- Debug/preview fixture files in `PhoneInTheOtherRoomLiveActivity/` and its widget source where needed;
- notification metadata adapters around `Shared/NotificationPlanning.swift` and production notification services, without scheduling real personal notifications during generation;
- preview/metadata adapters in `PhoneInTheOtherRoomScreenTimeReport/`;
- metadata/manual-evidence adapters for `PhoneInTheOtherRoomShieldConfiguration/` and `PhoneInTheOtherRoomShieldAction/`;
- surface-specific capture modules under `scripts/screenbook/lib/`;
- site filters/provenance presentation; and
- secondary-surface sections in `docs/PLAYBOOKS/screenbook.md`.

The exact target source files must be listed for founder review immediately before each adapter is implemented.

### Dependencies

Accepted iPhone pipeline; installed Watch/iOS runtimes; existing entitlements and physical devices where system evidence requires them. No new entitlement or target is assumed.

### Validation commands

Run XcodeGen, build every affected existing scheme/target, run the iPhone unit suite, run surface-specific capture/verify commands, and follow TestFlight/physical-device playbooks for entitlement-dependent evidence. Verify provenance labels in generated metadata and site.

### Visual QA

- Review Watch screenshots on actual Watch dimensions and paired navigation.
- Review all supported Live Activity families, including Lock Screen and relevant Dynamic Island states, without assuming preview parity.
- Check notification copy at payload level and on at least one supported simulator/physical presentation.
- Confirm report and shield evidence on a properly entitled physical device before calling it authoritative.
- Display OS/device/runtime and capture method next to system-controlled screenshots.

### Acceptance criteria

- Every secondary entry declares surface and capture provenance.
- Automated capture is used only where repeatable; manual evidence has an age/runtime warning and replacement procedure.
- No mocked system chrome is presented as an actual system capture.
- Production fixtures remain deterministic and side-effect free.
- Existing target builds, entitlements, and release behavior remain intact.
- Physical-device-only gaps are explicit rather than papered over.

### Stopping condition

Stop after each separately approved surface matrix is complete. A blocker in one extension must not cause speculative changes to entitlements or targets or block useful completed surfaces.

### Rollback

Remove one surface adapter/registry at a time and regenerate the site. Retain the established iPhone catalogue. Remove manual artifacts from the local Screenbook store without touching product assets or entitlements.

### Founder-confirmation gates

Before touching any secondary target, present the exact files and need. Stop for `project.yml`, target membership, bundle ID, signing, App Group, Family Controls, HealthKit, notification capability, or entitlement changes; physical-device capture/storage policy; or any proposed third-party simulator/snapshot tooling.

## Phase 6 — Optional hosting

### Scope

Optional future sharing of a read-only generated site after the local product is proven. Hosting is explicitly not MVP scope. Annotation persistence, authentication, confidential screenshots, review export storage, retention, and access revocation require a separate design and privacy decision.

### Exact likely files to add or modify

Unknown until a provider and threat model are approved. Likely additions would be deployment configuration, an access-control playbook, and generated-site publication rules. No provider configuration, analytics, database, domain, or repository action is pre-approved by this plan.

### Dependencies

Explicit founder approval of provider, budget, authentication, data classification, retention, collaborators, incident response, and whether annotations remain browser-local or become server data.

### Validation commands

Provider-specific preview deployment, authentication/access tests, remote-resource/analytics audit, cache invalidation test, deletion/revocation test, and a check that no secret or personal fixture data is included. Commands are selected only after approval.

### Visual QA

Compare hosted output to the local generated site, test authenticated desktop/mobile access, verify private images are not exposed through predictable unauthenticated URLs, and confirm review export behavior.

### Acceptance criteria

- Access is authenticated and least-privilege.
- No public indexing or anonymous asset access.
- No runtime AI requirement.
- Local generation remains the canonical workflow and works offline.
- Privacy, retention, deletion, and cost are documented.
- Hosting failure cannot block local Screenbook use.

### Stopping condition

Stop at a private proof with one approved collaborator. Public deployment remains a distinct future product decision.

### Rollback

Disable/delete the deployment through the approved provider, revoke access/tokens, verify asset deletion/cache expiry, remove deployment configuration, and continue using the local site.

### Founder-confirmation gates

Every hosting decision is a founder gate: provider, account, spend, domain, authentication, storage, collaborators, analytics, deployment source, and public/private status.

## 9. Sustainability analysis

### 9.1 Operations that consume zero AI tokens

The following are entirely local and deterministic:

- XcodeGen generation and app build;
- scenario listing and selection;
- fixture construction;
- simulator boot/configuration/install/launch;
- readiness polling and screenshot capture;
- metadata and copy-manifest generation;
- current/baseline hashing and visual/copy change detection;
- affected-scenario calculation;
- static site rebuild and local serving;
- search, filter, annotation, batch decision, import, and export in the browser;
- schema validation;
- single, changed, and full refresh;
- baseline acceptance; and
- local archival/deletion of generated artifacts.

None may hide a call to Codex, OpenAI, a hosted image service, a remote font/CDN, or an analytics service.

### 9.2 Operations where Codex is useful but optional

Codex is valuable for:

- interpreting nuanced editorial notes and resolving conflicts across reused copy;
- applying an approved review batch safely to Swift;
- checking wording against product principles and the product-copy-review skill;
- updating dynamic templates and associated tests;
- diagnosing a fixture/capture failure that deterministic logs do not make obvious;
- authoring new scenario fixtures or improving dependency mappings; and
- proposing durable founder-style guidance after explicit approval.

The founder can still hand-edit Swift or ask another developer to apply the same structured batch. The Screenbook itself remains functional without Codex.

### 9.3 Local build and storage costs

Costs are developer-machine time and disk space, not API fees. On the inspected Apple Silicon environment, expect an incremental build to range from seconds to roughly a minute and a clean build to take several minutes depending on DerivedData. A single settled capture should normally take tens of seconds; the five-scenario spike should complete in a few minutes after build. These are planning estimates, not acceptance thresholds.

A canonical iPhone PNG will commonly occupy roughly 1–5 MB depending on art/compression. One hundred current screenshots plus local baselines/diffs could use hundreds of megabytes to around 1 GB. DerivedData can be larger and remains managed separately. Browser annotations and JSON manifests are normally kilobytes to low megabytes.

The tool reports output sizes and free space. Generated images stay out of ordinary Git history, preventing clones and commits from accumulating image churn.

### 9.4 Economical copy batching

Review copy by coherent journey or theme, not one Codex task per string. An export should carry 10–50 compatible decisions when practical, plus source/current values and notes. One application pass can resolve reuse, run the copy skill once, edit related sources, build once, and capture the union of affected scenarios. Separate behavioral/product questions from straightforward approved replacements so uncertainty does not block the whole batch.

### 9.5 Avoiding unnecessary recapture

- Registry dependencies map copy/view/model/design/asset changes to scenarios.
- Stable copy IDs map an applied batch directly to scenario occurrences.
- One build can serve multiple captures.
- `--scenario` refreshes one state.
- `--changed` refreshes the dependency union.
- Site-only changes rebuild without the simulator.
- Global design-system, formatter, capture-profile, or uncertain dependency changes intentionally invalidate a broader set.
- Run a periodic full refresh before major founder review or release to catch mapping omissions; do not make every small edit pay that cost.

### 9.6 Preserving founder style durably

The review export is evidence of individual decisions, not automatically policy. After several accepted edits reveal a genuinely general rule, Codex should propose a concise amendment to `skills/product-copy-review/SKILL.md`, `docs/PRODUCT_PRINCIPLES.md`, or the appropriate decision record. The founder explicitly approves that amendment. Examples remain grounded in Counting Sheep, while one-off screen constraints stay in tokens/notes. This avoids both forgetting repeated preferences and overfitting canonical guidance to one phrase.

## 10. Risks and mitigations

| Risk | Mitigation and detection |
|---|---|
| Preview/Screenbook fixtures drift from production | Scenarios instantiate production views/models, registry dependencies are explicit, fixtures compile with the app, and periodic full captures plus journey review catch semantic drift. Do not duplicate layout in HTML. |
| Screenshots become stale | Fingerprints, copy/pixel hashes, stale badges, working-tree/source revision metadata, `--changed`, and periodic `--all` captures. A missing dependency fails toward broader capture. |
| Copy IDs lose source traceability | Semantic stable IDs, file + enclosing symbol anchors, original/authored/rendered values, occurrence lists, duplicate checks, and provisional status. Never use source line as identity. |
| Debug routes leak into Release | `#if DEBUG` around registry, arguments, fixtures, route, and readiness; Release build plus source/binary marker checks; normal no-argument launch test. |
| Large generated-image churn | Keep output under ignored local storage, version scripts/schemas rather than PNGs, selectively accept baselines, report disk usage, and avoid automatic Git staging. |
| Simulator instability | Dedicated device, `doctor`, fixed profile, run-ID readiness, bounded retry, atomic outputs, logs, and recovery playbook. Never use blind sleep as readiness. |
| Dynamic Type states are inaccessible or clipped | Add named profiles in Phase 3, make environment selectable in descriptors, capture priority text sizes, and record discovered product defects rather than changing snapshots to hide them. |
| System UI or entitlement-dependent surfaces are unreliable | Separate capture provenance, automate only stable app-owned states, retain manual physical-device evidence with runtime/date, and require Phase 5 target/entitlement gates. |
| Implementation expands into localization rewrite | Use lightweight tokens for selected copy, prohibit full String Catalog work in Phases 1–4 unless separately approved, and treat localization as a later product project. |
| Fixtures mutate user state or trigger side effects | Dedicated simulator, isolated store/dependency seams, fixed fake data, disabled external services, and tests that normal `ollie.*` state is not written. |
| Annotations disappear during regeneration | Browser storage separate from generated files, stable localhost origin, JSON import/export, schema migrations, and warnings before destructive cleanup. |
| A review applies against changed source | Original value and manifest hash in every item; dry-run source match; stale items blocked and returned for re-review. |
| Screenshot sameness is mistaken for correctness | Human visual QA remains required; change detection reports difference but does not decide product quality. |

## 11. Handoff prompts

These prompts deliberately keep phase boundaries and confirmation gates explicit.

### Phase 1 implementation prompt

> Implement only Phase 1 of `docs/SCREENBOOK_IMPLEMENTATION_PLAN.md`: the approved five-scenario iPhone technical spike. Read all canonical docs and the Screenbook plan first. Use a Debug-only launch-argument registry, production models with deterministic isolated fixtures, explicit readiness, `simctl` capture, Python-standard-library site generation, lightweight stable copy tokens, local annotations, structured review export, single-scenario refresh, and baseline/current drift detection. Add no dependency, target, entitlement, capability, tab, hosting, or `project.yml` change. Do not use `MVPMockData`. Stop and ask if any gated change becomes necessary. Implement exactly the five approved IDs, run every Phase 1 validation and visual QA check, show actual results and changed files, and do not begin Phase 2.

### Phase 2 implementation prompt

> Implement only Phase 2, Production hardening, from `docs/SCREENBOOK_IMPLEMENTATION_PLAN.md` after verifying Phase 1 acceptance. Harden and test the existing local pipeline without adding product scenarios or third-party dependencies. Preserve review/schema compatibility, make failure atomic and diagnosable, explain changed-scenario selection, and add native deterministic image diffing only if the Phase 1 evidence justifies it. Run Phase 1 and Phase 2 validation, report rollback compatibility, stop at the phase acceptance criteria, and do not begin catalogue expansion.

### Phase 3 implementation prompt

> Implement only the founder-approved iPhone catalogue matrix under Phase 3 of `docs/SCREENBOOK_IMPLEMENTATION_PLAN.md`. Distinguish screens, scenarios, and embedded components. Use real production views/models, deterministic Debug fixtures, stable IDs, and incremental copy tokens; never use gated MVP mock data. Add only the approved states/profiles, keep production behavior and persistence unchanged, run changed and full verification plus visual journey QA, and stop when the approved matrix is complete. Ask before any gated project, target, dependency, navigation, or persistence change.

### Phase 4 implementation prompt

> Implement only Phase 4's copy workflow after iPhone catalogue acceptance. Add deterministic batch validation and stale-source protection, keep the website proposal-only, and exercise one founder-approved review JSON batch end-to-end. Use `skills/product-copy-review/SKILL.md`, apply only approved stable-ID items, run build/tests, recapture only the dependency union, and present before/after copy and visuals for final founder approval. Do not start String Catalog migration or turn one-off edits into canonical policy without explicit approval.

### Phase 5 implementation prompt

> Plan and implement one explicitly approved secondary Apple surface from Phase 5 of `docs/SCREENBOOK_IMPLEMENTATION_PLAN.md`. Before editing, list the exact existing target files and explain the capture provenance. Keep target/project/entitlement/signing configuration unchanged unless the founder separately approves the exact need. Automate only reproducible app-authored states; label system/manual physical-device evidence honestly. Validate every affected target and stop after the selected surface, not the entire phase.

### Phase 6 implementation prompt

> Do not deploy yet. Convert Phase 6 of `docs/SCREENBOOK_IMPLEMENTATION_PLAN.md` into a provider-specific private-hosting proposal covering authentication, confidential assets, annotation storage, retention/deletion, cost, collaborators, rollback, and continued offline local operation. Make no account, domain, deployment, dependency, analytics, or configuration change until the founder approves each gate.

### Final audit prompt

> Audit the completed Screenbook against `AGENTS.md`, all canonical product/architecture docs, `skills/product-copy-review/SKILL.md`, and `docs/SCREENBOOK_IMPLEMENTATION_PLAN.md`. Do not implement fixes. Verify source-of-truth boundaries, debug/release isolation, deterministic fixtures, zero-model regeneration, scenario/copy ID integrity, capture readiness, local privacy, generated-artifact policy, incremental/full refresh correctness, review import/export and stale protection, visual verification, secondary-surface provenance, dependencies, XcodeGen integrity, and all phase acceptance/gates. Re-run safe read-only validations where appropriate. Report findings by severity with exact file references, distinguish product defects from Screenbook defects, list unverified physical/system behavior, and state whether each completed phase truly meets its stopping condition.

### Routine copy-batch prompt

> Apply the attached founder-approved Screenbook copy-review JSON as one bounded batch. Read `AGENTS.md`, the canonical product-copy documents, `skills/product-copy-review/SKILL.md`, the Screenbook plan/playbook, and validate the JSON schema first. Dry-run every item against stable copy ID, source anchor, original authored/rendered value, and manifest hash. Do not apply open, rejected, needs-discussion, provisional, unknown, duplicated, conflicting, or stale items. For approved current items, edit the authoritative Swift copy only, preserve dynamic parameters and behavior, run the required build/tests, recapture only the union of affected scenarios, rebuild the local site, and show before/after copy and visuals. Do not change product behavior, start localization migration, modify project configuration, or create policy from one-off feedback. Return unresolved items in a structured report and stop for founder approval of the rendered result.

## 12. Decision summary

### Recommended architecture

Use a Debug-only Swift scenario registry selected by launch argument, rendering real production views/models with deterministic isolated fixtures. Drive it with a zero-dependency local CLI built on Python standard library, `xcodebuild`, and `simctl`; obtain registry metadata from the app, wait on a run-specific readiness handshake, generate a vanilla static local site, store annotations in browser-local storage, and export versioned review JSON. Use lightweight semantic `AppCopyToken` IDs for reviewable production copy. Keep screenshots, baselines, diffs, and generated site output local and ignored. Codex is optional only for judgment and applying approved source changes.

### Exact technical-spike boundary

The approved spike contains exactly five canonical iPhone simulator scenarios:

- `iphone.onboarding.welcome.default`
- `iphone.home.configured.default`
- `iphone.home.active-wind-down.default`
- `iphone.home.early-end.default`
- `iphone.farm.populated.default`

It proves registry identity, deterministic fixtures, capture readiness, automated local capture, metadata/copy mapping, searchable gallery, local annotations, structured review round-trip, one-scenario refresh, baseline/current visual and copy comparison, failure safety, and Release isolation. It adds no sixth scenario, secondary Apple surface, application of copy revisions, String Catalog, dependency, project/target/entitlement change, or hosting.

### Decisions the founder must make before implementation

No additional decision is required to begin the technical spike as bounded above; approval of this plan is approval of that phase and its canonical capture profile. Implementation must still stop if repository facts reveal a need to change `project.yml`, a target, entitlements/capabilities/signing, release routing or tabs, persisted formats, dependencies, personal-data handling, or hosting. Any substitution of the canonical simulator because iOS 26.5/iPhone 17 is unavailable must be reported before baselines are established.

### Decisions that can safely wait

- the complete iPhone catalogue matrix and priority order;
- additional devices, OS versions, appearances, Dynamic Type sizes, locales, and accessibility matrices;
- native heat-map/tolerance sophistication beyond clear hash/diff reporting;
- UI-test or snapshot-library adoption;
- String Catalog/localization migration;
- Watch, Live Activity, notification, report-extension, and shield capture matrices;
- whether any generated baselines belong in source control or external artifact storage;
- collaboration, hosting provider, authentication, remote annotation storage, analytics, and public access; and
- Figma or other one-way design reference exports.

### Estimated maintenance characteristics

Normal operation is local and token-free. A copy-only or localized view change should require one incremental build and capture of the mapped scenario union; a site/template change requires no simulator. Adding a well-understood scenario should be a small fixture/registry task, while unusual permission/system states remain intentionally manual or separately adapted. The five-scenario spike should regenerate in minutes after build; a mature catalogue may take tens of minutes for a full refresh but should usually use changed/single refresh. Local screenshot storage grows by megabytes per scenario and potentially hundreds of megabytes for a mature current+baseline set, while Git receives only small source/schema/tool changes by default. Codex cost is concentrated into economical approved copy batches and occasional engineering judgment, never routine Screenbook regeneration.
