#!/usr/bin/env python3
"""Run actual Foundation file-store tests without changing Xcode targets."""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="counting-sheep-farm-tests-") as temporary:
    package = Path(temporary)
    sources = package / "Sources" / "FarmSaveValidation"
    tests = package / "Tests" / "FarmSaveValidationTests"
    sources.mkdir(parents=True)
    tests.mkdir(parents=True)
    for source in (repo / "Shared").rglob("*.swift"):
        if source.name == "FocusRunLiveActivity.swift":
            # The host SDK exposes ActivityKit to canImport even though its
            # attributes are iOS-only. Keep the pure models and omit that block
            # in this host harness; the real iOS build checks ActivityKit.
            (sources / source.name).write_text(source.read_text().replace(
                "#if canImport(ActivityKit)", "#if canImport(ActivityKit) && os(iOS)"))
        else:
            (sources / source.name).symlink_to(source)
    for name in ["FarmSaveStore.swift", "FarmSaveStore+Accounts.swift", "PersistenceService.swift", "PersistenceService+WindDownHabit.swift", "PersistenceService+Personalisation.swift", "FarmSyncConnectivityService.swift"]:
        (sources / name).symlink_to(repo / "PhoneInTheOtherRoomApp" / "Services" / name)
    for name in ["FarmBackupViewModel.swift", "FarmBackupPresentation.swift", "FarmBackupViewModel+AccountSync.swift", "FarmBackupViewModel+Recovery.swift", "FarmBackupViewModel+Retry.swift", "PasswordAccountViewModel.swift"]:
        (sources / name).symlink_to(repo / "PhoneInTheOtherRoomApp/ViewModels" / name)
    (sources / "FarmBackupTestDoubles.swift").symlink_to(
        repo / "scripts/support/FarmBackupTestDoubles.swift")
    for name in ["FarmBackupViewModelTests.swift", "FarmSaveDocumentTests.swift", "FarmSaveStoreTests.swift", "FarmPersistenceAdapterTests.swift", "AccountFarmStoreTests.swift", "AccountFarmOwnershipTests.swift", "RitualPersonalisationPersistenceTests.swift"]:
        (tests / name).write_text("@testable import FarmSaveValidation\n" + (repo / "Tests" / name).read_text())
    (package / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FarmSaveValidation", platforms: [.macOS(.v14)], targets: [
    .target(name: "FarmSaveValidation"),
    .testTarget(name: "FarmSaveValidationTests", dependencies: ["FarmSaveValidation"],
        swiftSettings: [.define("FARM_SAVE_SERVICE_TESTS"), .define("FARM_BACKUP_VIEW_MODEL_TESTS")])
])
''')
    subprocess.run(["swift", "test", "--package-path", str(package), "--jobs", "4"], check=True)
