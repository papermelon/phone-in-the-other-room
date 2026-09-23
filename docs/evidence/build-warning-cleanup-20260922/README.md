# Build warning cleanup — 22 September 2026

The founder's screenshots showed 17 issues from a Release archive: one project recommendation, one ExtensionKit embedding warning, ten Swift warnings in the app, and the same unreachable Campfire branch in five targets (including the app).

## Changes

- Select the supported PostgREST initializer explicitly with `logger: nil`; account-pinned authorization remains unchanged.
- Remove unused NFC, social and Barn bindings; retain the account-availability guard during sign-out without an unused binding.
- Explicitly discard the three refresh results whose callers already rely on published state, and the removed account-recovery dictionary entry. Preserve the transaction and all callers that branch on refresh success.
- Remove the unreachable Campfire default: both existing occurrence roles are handled exhaustively.
- Adopt the three recommendations selected by Xcode 26.6: dead-code stripping, user-script sandboxing, and String Catalog symbol generation. Update XcodeGen's version metadata only after reviewing those recommendations. The unselected asset-symbol option stays unchanged.
- Embed Screen Time Report relative to the app wrapper's `Extensions` directory. The prior products-directory base resolved outside the installed app during archiving. This is configured in `project.yml` using XcodeGen's [dependency copy destination](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#dependency), then regenerated; no signing or entitlement changes.

## Validation

- `xcodegen generate` and `git diff --check`: passed.
- Full generic iOS Simulator build: passed. None of the pictured Swift or embedding warnings remain in `/tmp/warning-cleanup-build.log`.
- Full unit suite on iPhone 17e: **1,112 tests, zero failures**, `/tmp/warning-cleanup-tests.log` and `/tmp/warning-cleanup-tests.xcresult`.
- Xcode UI: the project-level “Update to recommended settings” advisory disappeared after regeneration. The navigator still retains historical issues from the earlier archive until a new build replaces that report.
- Unsigned Release `install` build: **passed**, `/tmp/warning-cleanup-release-install.log`. Xcode validated Screen Time Report at `InstallationBuildProductsLocation/Applications/Counting Sheep.app/Extensions/Counting Sheep Screen Time Report.appex`, with no ExtensionKit placement warning. All pictured compiler warnings were absent in this fresh optimized device build.
- Generated-project inspection: exactly one copy phase embeds the report, using the app-wrapper destination and `Extensions` subpath.

Commands (run from the repository root):

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/slumber-repair-derived -disableAutomaticPackageResolution
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=71CF8F3E-9E9A-449D-93A8-B73F64869A5E' -derivedDataPath /tmp/slumber-repair-derived -disableAutomaticPackageResolution -resultBundlePath /tmp/warning-cleanup-tests.xcresult
xcodebuild install -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/slumber-repair-derived -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO
```

Xcode still emits separate App Intents metadata notices for targets without AppIntents. They are unrelated to the screenshots; no framework was added or diagnostic disabled to hide them. No release archive or upload is performed by this task. The unsigned install build is local packaging validation, not signed-device acceptance.
