# Creating a uniquely numbered release archive

Use this workflow for every new TestFlight/release archive, including archives requested
in future agent prompts. It does not upload, change signing, or replace release acceptance.
The supported entry point is the script, not Xcode's Product > Archive menu.

## Command

From the repository root, check the highest uploaded build in App Store Connect/TestFlight,
then run (replace `41` with that confirmed value):

```bash
python3 scripts/archive-release.py --latest-uploaded 41 --dry-run
python3 scripts/archive-release.py --latest-uploaded 41
```

The dry run prints the next candidate without reserving it or changing the project.
The real command:

1. Takes a Mac-wide release lock, shared across checkouts.
2. Chooses one above the maximum of the project setting, matching local Xcode archive
   numbers, previous reservations on this Mac, and the supplied uploaded maximum.
3. Persists the reservation, updates only `CURRENT_PROJECT_VERSION` in `project.yml`,
   and runs `xcodegen generate`.
4. Creates a signed Release archive under `~/Library/Developer/Xcode/Archives`, using
   an explicit build-number override so every target receives the reserved number.
5. Checks the main app, every nested `.app` and `.appex`, their marketing/build versions,
   expected bundle IDs from `project.yml` (excluding the unit test bundle), and the
   Organizer build-number metadata. Missing or unexpected bundles fail verification.

Xcode and XcodeGen must be installed, and existing signing must already work. The script
never passes provisioning-update flags or changes signing settings. Source changes and
normal validation should be complete before starting. Avoid editing/regenerating the
project or running another archive outside this workflow while the command runs.

## Upload and retries

Open the printed archive in Xcode Organizer (or double-click its `.xcarchive`) and use
Distribute App. Use Custom distribution options if needed to disable **Manage version
and build number**, keeping the uploaded number identical to the verified archive.
Upload/production distribution still requires explicit authorization when an agent acts.

An upload retry uses the existing archive and number. A new archive invocation reserves
a new number, including after a failed build. Gaps in build numbers are intentional.
The counter is stored at `~/Library/Application Support/Counting Sheep Release/build-number.json`.
Do not delete/reset it to reuse a failed number. A failed build leaves the project bump
in place; fix the failure and run the command again.

The command does not query App Store Connect. A supplied stale number can still collide
with a build uploaded elsewhere. Coordinate releases from other Macs/CI and refresh the
uploaded maximum before running; the lock only covers this Mac. Direct Product > Archive
continues to reuse the project number and bypasses these protections.

## Validation

```bash
python3 -m unittest discover -s scripts/tests -p 'test_archive_release.py' -v
```

Tests use disposable archives and mocked build commands: they cover allocation, persistent
reservations, concurrency, dry run, generation failure, command order and bundle checking.
A passing script suite does not establish that a real signed archive or upload succeeded.
