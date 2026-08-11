# Playbook: Local Screenbook technical spike

The Screenbook is a private, generated review surface for five deterministic production iPhone
states. Swift and the production models remain authoritative. The gallery displays simulator
screenshots and metadata; it never rebuilds the product UI in HTML and never edits Swift.

## Requirements

- Xcode 26.6 with the iOS 26.5 runtime and iPhone 17 simulator device type
- XcodeGen, Python 3, `xcrun simctl`, and `sips`
- at least 8 GB free local disk space

No API key, network service, package manager, third-party dependency, model, or AI call is used by
any refresh command. Generated screenshots, manifests, baselines, logs, and the built site live
under ignored `tmp/screenbook/`.

## First capture and open

```bash
python3 scripts/screenbook/screenbook.py doctor
python3 scripts/screenbook/screenbook.py capture --all
python3 scripts/screenbook/screenbook.py verify
python3 scripts/screenbook/screenbook.py serve
```

Open `http://127.0.0.1:4173/site/index.html`. The server binds only to `127.0.0.1` and loads no
remote resources. Stop it with Control-C.

## Zero-token refresh modes

```bash
# One production state; every unrelated artifact and browser annotation stays untouched.
python3 scripts/screenbook/screenbook.py capture --scenario iphone.farm.populated.default

# Dependency and fixture fingerprints select the affected scenario union.
python3 scripts/screenbook/screenbook.py capture --changed

# Rebuild and capture the exact five-state technical spike.
python3 scripts/screenbook/screenbook.py capture --all

# Rebuild HTML/CSS/JavaScript from valid local artifacts without a simulator.
python3 scripts/screenbook/screenbook.py build-site

# Accept one current image/copy record as a local comparison baseline.
python3 scripts/screenbook/screenbook.py accept-baseline --scenario iphone.farm.populated.default
```

Every capture prints its exact scenario set. A scenario is staged and promoted atomically only
after the Debug app writes a matching run-ID readiness signal and the PNG passes validation.
Failure preserves the previous current artifact.

## Copy review

Open a scenario, leave a screen note or a proposed replacement, choose a decision, and use
**Export review JSON**. Browser annotations use the versioned local-storage key
`counting-sheep.screenbook.annotations.v1`, so rebuilding the generated site on the same local
origin preserves them. Export before clearing browser data.

Validate an exported batch without applying it:

```bash
python3 scripts/screenbook/screenbook.py validate-review /absolute/path/to/review.json
```

The validator rejects duplicate IDs, unknown decisions or sources, stale rendered values and
manifest hashes, and approval of provisional mappings. Import keeps stale items but changes their
decision to `needs-discussion`. Neither import nor export modifies Swift.

## Recovery

The dedicated simulator is named `Counting Sheep Screenbook iPhone 17`. If it is stopped, the next
capture boots it. If it is wedged, shut down only that resolved simulator and rerun the command:

```bash
xcrun simctl shutdown "Counting Sheep Screenbook iPhone 17"
python3 scripts/screenbook/screenbook.py doctor
```

Do not erase unrelated simulators. The disposable output can be moved to Trash by targeting only
the resolved `tmp/screenbook/` directory. Browser annotations require their separate JSON export.

## Phase boundary

The registry must list exactly the five approved Phase 1 identifiers. Do not add catalogue states,
localization, Watch, Live Activity, notification, report-extension, shield, deployment, hosting,
or copy-application behavior here. Those are later separately approved phases in
`docs/SCREENBOOK_IMPLEMENTATION_PLAN.md`.
