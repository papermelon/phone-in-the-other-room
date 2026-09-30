#!/usr/bin/env python3
"""Synthetic Swift ↔ Kotlin exchange through existing production Swift codecs, no app data/network."""
from pathlib import Path
import subprocess
import shutil
import tempfile
import hashlib

repo = Path(__file__).resolve().parents[2]
android = repo / 'android'
with tempfile.TemporaryDirectory(prefix='counting-sheep-android-codec-') as temporary:
    package = Path(temporary)
    sources = package / 'Sources' / 'CodecProof'
    sources.mkdir(parents=True)
    for source in (repo / 'Shared').rglob('*.swift'):
        if source.name == 'OllieWardrobe.swift':
            # Host CGPoint lacks Equatable; remove only this unrelated rendering conformance.
            (sources / source.name).write_text(source.read_text().replace(
                'struct OllieNeckwearPose: Equatable {', 'struct OllieNeckwearPose {'))
            continue
        if source.name == 'FocusRunLiveActivity.swift':
            (sources / source.name).write_text(source.read_text().replace(
                '#if canImport(ActivityKit)', '#if canImport(ActivityKit) && os(iOS)'))
        else:
            (sources / source.name).symlink_to(source)
    (sources / 'DomainReference.swift').symlink_to(android / 'compatibility' / 'DomainReference.swift')
    (sources / 'main.swift').symlink_to(android / 'compatibility' / 'main.swift')
    for name in ['FarmSaveStore.swift', 'FarmSaveStore+Accounts.swift']:
        (sources / name).symlink_to(repo / 'PhoneInTheOtherRoomApp' / 'Services' / name)
    tests = package / 'Tests' / 'SwiftRuleTests'
    tests.mkdir(parents=True)
    for name in ['NightWatchTests.swift', 'WindDownSchedulingTests.swift', 'IndependentMorningSettlementTests.swift',
                 'CumulativeFarmCreditTests.swift', 'BedtimeSearchBonusTests.swift', 'QuietTimeBriefAccessTests.swift',
                 'WelcomeRewardTests.swift', 'FarmEconomyTests.swift', 'FarmSaveDocumentTests.swift', 'FarmSaveStoreTests.swift', 'HomeStartRoutingTests.swift', 'PersonalShieldTests.swift']:
        (tests / name).write_text('@testable import CodecProof\n' + (repo / 'Tests' / name).read_text())
    (package / 'Package.swift').write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CodecProof", platforms: [.macOS(.v14)], targets: [.executableTarget(name: "CodecProof"), .testTarget(name: "SwiftRuleTests", dependencies: ["CodecProof"])])
''')
    subprocess.run(['swift', 'build', '--package-path', str(package), '--jobs', '4'], check=True)
    subprocess.run(['swift', 'test', '--package-path', str(package), '--jobs', '4'], check=True)
    binary = package / '.build' / 'debug' / 'CodecProof'
    fixtures = android / 'compatibility' / 'fixtures'
    exchange = android / 'build' / 'compatibility'
    shutil.rmtree(exchange, ignore_errors=True)
    generated = package / 'GeneratedFixtures'
    subprocess.run([str(binary), 'generate', str(generated)], check=True)
    first = hashlib.sha256((generated / 'domain-reference.json').read_bytes()).hexdigest()
    subprocess.run([str(binary), 'generate', str(generated)], check=True)
    assert first == hashlib.sha256((generated / 'domain-reference.json').read_bytes()).hexdigest(), 'Nondeterministic Swift domain fixtures'
    print('PASS: deterministic current-Swift domain fixture generation', flush=True)
    subprocess.run([str(binary), 'compare', str(generated), str(fixtures)], check=True)
    shutil.copyfile(generated / 'domain-reference.json', fixtures / 'domain-reference.json')
    subprocess.run([str(android / 'gradlew'), '-p', str(android), '--offline', ':app:testDebugUnitTest', '--tests', '*FarmPayloadCodecTest', '--tests', '*DomainParityTest', '--rerun-tasks'], check=True)
    subprocess.run([str(binary), 'verify', str(fixtures), str(exchange)], check=True)
    subprocess.run([str(android / 'gradlew'), '-p', str(android), '--offline', ':app:testDebugUnitTest', '--tests', '*FarmPayloadCodecTest', '--tests', '*DomainParityTest', '--rerun-tasks', '-DverifySwift=true'], check=True)
