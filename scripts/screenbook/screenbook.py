#!/usr/bin/env python3
"""Deterministic local capture and gallery workflow for the Phase 1 Screenbook spike."""

from __future__ import annotations

import argparse
import binascii
import contextlib
import hashlib
import http.server
import json
import os
import plistlib
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import uuid
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "tmp" / "screenbook"
DERIVED = WORK / "DerivedData"
CURRENT = WORK / "current"
BASELINE = WORK / "baseline"
GENERATED_SITE = WORK / "site"
REGISTRY_PATH = WORK / "registry.json"
CURRENT_MANIFEST = CURRENT / "manifest.json"
BASELINE_MANIFEST = BASELINE / "manifest.json"
SITE_SOURCE = Path(__file__).resolve().parent / "site"
BUNDLE_ID = "com.ngawangchime.countingsheep"
SIMULATOR_NAME = "Counting Sheep Screenbook iPhone 17"
RUNTIME_ID = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
DEVICE_TYPE_NAME = "iPhone 17"
CAPTURE_PROFILE = "iphone17-ios26.5-enSG-standard"
SERVER_PORT = 4173


class ScreenbookError(RuntimeError):
    pass


def command(args: list[str], *, check: bool = True, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        args,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=env,
    )
    if check and result.returncode:
        raise ScreenbookError(f"Command failed ({result.returncode}): {' '.join(args)}\n{result.stdout[-5000:]}")
    return result


def read_json(path: Path, default=None):
    if not path.exists():
        return default
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json_atomic(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as handle:
        json.dump(value, handle, indent=2, sort_keys=True, ensure_ascii=False)
        handle.write("\n")
        temporary = Path(handle.name)
    os.replace(temporary, path)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def stable_hash(value) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return sha256_bytes(encoded)


def source_revision() -> str:
    revision = command(["git", "rev-parse", "HEAD"]).stdout.strip()
    dirty = command(["git", "status", "--porcelain"]).stdout.strip()
    return f"{revision}-dirty" if dirty else revision


def simulator_inventory() -> dict:
    return json.loads(command(["xcrun", "simctl", "list", "-j", "devices", "runtimes", "devicetypes"]).stdout)


def canonical_runtime_and_device_type(inventory: dict) -> tuple[dict, dict]:
    runtime = next((item for item in inventory["runtimes"] if item["identifier"] == RUNTIME_ID and item.get("isAvailable", True)), None)
    device_type = next((item for item in inventory["devicetypes"] if item["name"] == DEVICE_TYPE_NAME), None)
    if not runtime:
        raise ScreenbookError("Required canonical runtime iOS 26.5 is unavailable.")
    if not device_type:
        raise ScreenbookError("Required canonical device type iPhone 17 is unavailable.")
    return runtime, device_type


def simulator_udid(*, create: bool) -> str:
    inventory = simulator_inventory()
    runtime, device_type = canonical_runtime_and_device_type(inventory)
    candidates = inventory["devices"].get(runtime["identifier"], [])
    existing = next((item for item in candidates if item["name"] == SIMULATOR_NAME and item.get("isAvailable", True)), None)
    if existing:
        return existing["udid"]
    if not create:
        return "not-created"
    return command([
        "xcrun", "simctl", "create", SIMULATOR_NAME,
        device_type["identifier"], runtime["identifier"],
    ]).stdout.strip()


def doctor(_args=None) -> None:
    missing = [name for name in ("xcodebuild", "xcrun", "xcodegen", "python3", "sips") if shutil.which(name) is None]
    if missing:
        raise ScreenbookError(f"Missing required commands: {', '.join(missing)}")
    runtime, device_type = canonical_runtime_and_device_type(simulator_inventory())
    free = shutil.disk_usage(ROOT).free
    if free < 8 * 1024**3:
        raise ScreenbookError(f"At least 8 GB free is required; found {free / 1024**3:.1f} GB.")
    print("Screenbook doctor: ready")
    print(f"  Xcode: {command(['xcodebuild', '-version']).stdout.splitlines()[0]}")
    print(f"  Runtime: {runtime['name']} ({runtime.get('version', '26.5')})")
    print(f"  Device: {device_type['name']}")
    print(f"  Simulator: {simulator_udid(create=False)}")
    print(f"  Python: {sys.version.split()[0]}")
    print(f"  Free space: {free / 1024**3:.1f} GB")
    print("  Network/model runtime: not used")


def boot_and_normalize(udid: str) -> None:
    command(["xcrun", "simctl", "boot", udid], check=False)
    command(["xcrun", "simctl", "bootstatus", udid, "-b"])
    command(["xcrun", "simctl", "ui", udid, "appearance", "light"])
    command(["xcrun", "simctl", "status_bar", udid, "clear"], check=False)
    command([
        "xcrun", "simctl", "status_bar", udid, "override",
        "--time", "9:41", "--operatorName", "Counting Sheep",
        "--wifiBars", "3", "--cellularBars", "4", "--batteryLevel", "100", "--batteryState", "charged",
    ])
    preferences = [
        ["xcrun", "simctl", "spawn", udid, "defaults", "write", "com.apple.Accessibility", "ReduceMotionEnabled", "-bool", "YES"],
        ["xcrun", "simctl", "spawn", udid, "defaults", "write", "NSGlobalDomain", "AppleLanguages", "-array", "en"],
        ["xcrun", "simctl", "spawn", udid, "defaults", "write", "NSGlobalDomain", "AppleLocale", "en_SG"],
        ["xcrun", "simctl", "spawn", udid, "defaults", "write", "NSGlobalDomain", "UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"],
    ]
    for item in preferences:
        command(item)


def build_app(udid: str) -> Path:
    command(["xcodegen", "generate"])
    DERIVED.mkdir(parents=True, exist_ok=True)
    result = command([
        "xcodebuild", "build",
        "-project", "PhoneInTheOtherRoom.xcodeproj",
        "-scheme", "PhoneInTheOtherRoom",
        "-configuration", "Debug",
        "-destination", f"platform=iOS Simulator,id={udid}",
        "-derivedDataPath", str(DERIVED),
    ])
    (WORK / "logs").mkdir(parents=True, exist_ok=True)
    (WORK / "logs" / "build.log").write_text(result.stdout, encoding="utf-8")
    app = DERIVED / "Build" / "Products" / "Debug-iphonesimulator" / "Counting Sheep.app"
    if not app.exists():
        raise ScreenbookError(f"Built app was not found at {app}")
    with (app / "Info.plist").open("rb") as handle:
        if plistlib.load(handle).get("CFBundleIdentifier") != BUNDLE_ID:
            raise ScreenbookError("Built app bundle identifier does not match the Screenbook contract.")
    return app


def install_app(udid: str, app: Path) -> Path:
    command(["xcrun", "simctl", "install", udid, str(app)])
    return Path(command(["xcrun", "simctl", "get_app_container", udid, BUNDLE_ID, "data"]).stdout.strip())


def remove_readiness(container: Path) -> None:
    readiness = container / "Documents" / "screenbook" / "readiness.json"
    with contextlib.suppress(FileNotFoundError):
        readiness.unlink()


def launch_and_wait(udid: str, container: Path, launch_arguments: list[str], run_id: str, timeout: float = 25) -> dict:
    remove_readiness(container)
    command(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], check=False)
    environment = dict(os.environ)
    environment["SIMCTL_CHILD_TZ"] = "Asia/Singapore"
    environment["SIMCTL_CHILD_AppleLanguages"] = "(en)"
    environment["SIMCTL_CHILD_AppleLocale"] = "en_SG"
    result = command(["xcrun", "simctl", "launch", udid, BUNDLE_ID, *launch_arguments, "-screenbook-run-id", run_id], env=environment)
    readiness = container / "Documents" / "screenbook" / "readiness.json"
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        signal = read_json(readiness)
        if signal and signal.get("runID") == run_id:
            if signal.get("status") != "ready":
                raise ScreenbookError(signal.get("message") or "Screenbook fixture reported failure.")
            return signal
        time.sleep(0.1)
    diagnostics = command(["xcrun", "simctl", "spawn", udid, "log", "show", "--last", "1m", "--predicate", f'process == "{BUNDLE_ID}"'], check=False).stdout
    (WORK / "logs").mkdir(parents=True, exist_ok=True)
    (WORK / "logs" / f"timeout-{run_id}.log").write_text(result.stdout + "\n" + diagnostics, encoding="utf-8")
    raise ScreenbookError(f"Timed out waiting for readiness run {run_id}; the last valid artifact was preserved.")


def validate_registry(registry: dict) -> None:
    if registry.get("schemaVersion") != 1 or registry.get("captureProfile") != CAPTURE_PROFILE:
        raise ScreenbookError("Unsupported registry schema or capture profile.")
    scenarios = registry.get("scenarios", [])
    identifiers = [item.get("id") for item in scenarios]
    if len(scenarios) != 5 or len(set(identifiers)) != len(identifiers) or any(not value for value in identifiers):
        raise ScreenbookError("Phase 1 registry must contain exactly five unique scenario identifiers.")
    for scenario in scenarios:
        copy_ids = [item.get("id") for item in scenario.get("copy", [])]
        if len(copy_ids) != len(set(copy_ids)):
            raise ScreenbookError(f"Duplicate copy ID in {scenario['id']}")


def export_registry(udid: str, container: Path) -> dict:
    run_id = str(uuid.uuid4())
    launch_and_wait(udid, container, ["-screenbook-export-manifest", "YES"], run_id)
    source = container / "Documents" / "screenbook" / "registry.json"
    registry = read_json(source)
    if not registry:
        raise ScreenbookError("The Debug app did not export its scenario registry.")
    validate_registry(registry)
    write_json_atomic(REGISTRY_PATH, registry)
    return registry


def prepare_capture_build() -> tuple[str, Path, Path, dict]:
    doctor()
    udid = simulator_udid(create=True)
    boot_and_normalize(udid)
    app = build_app(udid)
    container = install_app(udid, app)
    registry = export_registry(udid, container)
    return udid, app, container, registry


def dependency_digest(paths: list[str]) -> str:
    entries: list[tuple[str, str]] = []
    for relative in sorted(paths):
        path = ROOT / relative
        if not path.exists():
            raise ScreenbookError(f"Registered dependency is missing: {relative}")
        if path.is_dir():
            files = sorted(item for item in path.rglob("*") if item.is_file())
        else:
            files = [path]
        for item in files:
            entries.append((str(item.relative_to(ROOT)), sha256_file(item)))
    return stable_hash(entries)


def scenario_fingerprint(scenario: dict) -> str:
    material = {
        "toolVersion": 1,
        "schemaVersion": 1,
        "captureProfile": CAPTURE_PROFILE,
        "id": scenario["id"],
        "fixtureVersion": scenario["fixtureVersion"],
        "descriptor": scenario,
        "dependencies": dependency_digest(scenario["dependencies"]),
    }
    return stable_hash(material)


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ScreenbookError(f"Capture is not a valid PNG: {path}")
    return struct.unpack(">II", header[16:24])


def _paeth(left: int, above: int, upper_left: int) -> int:
    prediction = left + above - upper_left
    left_distance = abs(prediction - left)
    above_distance = abs(prediction - above)
    upper_left_distance = abs(prediction - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    return above if above_distance <= upper_left_distance else upper_left


def decode_rgba_png(path: Path) -> tuple[int, int, bytearray]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ScreenbookError(f"Capture is not a valid PNG: {path}")
    offset = 8
    compressed = bytearray()
    width = height = 0
    while offset < len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR":
            width, height, depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            if (depth, color_type, compression, filtering, interlace) != (8, 6, 0, 0, 0):
                raise ScreenbookError("Screenbook capture canonicalization requires non-interlaced 8-bit RGBA PNGs.")
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break
    row_bytes = width * 4
    encoded = zlib.decompress(bytes(compressed))
    if len(encoded) != height * (row_bytes + 1):
        raise ScreenbookError("Unexpected PNG scanline length during capture canonicalization.")
    pixels = bytearray(height * row_bytes)
    prior = bytearray(row_bytes)
    source_offset = 0
    for row in range(height):
        filter_kind = encoded[source_offset]
        source_offset += 1
        filtered = encoded[source_offset:source_offset + row_bytes]
        source_offset += row_bytes
        decoded = bytearray(row_bytes)
        for index, value in enumerate(filtered):
            left = decoded[index - 4] if index >= 4 else 0
            above = prior[index]
            upper_left = prior[index - 4] if index >= 4 else 0
            if filter_kind == 0:
                decoded[index] = value
            elif filter_kind == 1:
                decoded[index] = (value + left) & 0xFF
            elif filter_kind == 2:
                decoded[index] = (value + above) & 0xFF
            elif filter_kind == 3:
                decoded[index] = (value + ((left + above) // 2)) & 0xFF
            elif filter_kind == 4:
                decoded[index] = (value + _paeth(left, above, upper_left)) & 0xFF
            else:
                raise ScreenbookError(f"Unsupported PNG filter {filter_kind} during capture canonicalization.")
        start = row * row_bytes
        pixels[start:start + row_bytes] = decoded
        prior = decoded
    return width, height, pixels


def write_rgba_png(path: Path, width: int, height: int, pixels: bytearray) -> None:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        checksum = binascii.crc32(kind + payload) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", checksum)

    row_bytes = width * 4
    scanlines = bytearray()
    for row in range(height):
        scanlines.append(0)
        start = row * row_bytes
        scanlines.extend(pixels[start:start + row_bytes])
    contents = b"\x89PNG\r\n\x1a\n"
    contents += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    contents += chunk(b"IDAT", zlib.compress(bytes(scanlines), level=9))
    contents += chunk(b"IEND", b"")
    path.write_bytes(contents)


def canonicalize_transient_home_indicator(path: Path) -> None:
    """Remove only the simulator-controlled fading pill while preserving the app pixels."""
    width, height, pixels = decode_rgba_png(path)
    if height < 80:
        return
    row_bytes = width * 4
    first = height - 44
    last = height - 17
    top = pixels[(first - 1) * row_bytes:first * row_bytes]
    bottom = pixels[last * row_bytes:(last + 1) * row_bytes]
    span = last - first + 1
    for row in range(first, last + 1):
        numerator = row - first + 1
        start = row * row_bytes
        for index in range(row_bytes):
            pixels[start + index] = (top[index] * (span - numerator) + bottom[index] * numerator) // span
    write_rgba_png(path, width, height, pixels)


def pixel_hash(path: Path) -> str:
    with tempfile.TemporaryDirectory(prefix="screenbook-pixels-") as directory:
        bitmap = Path(directory) / "pixels.bmp"
        result = command(["sips", "-s", "format", "bmp", str(path), "--out", str(bitmap)], check=False)
        if result.returncode or not bitmap.exists():
            return sha256_file(path)
        data = bitmap.read_bytes()
        return sha256_bytes(data[54:] if len(data) > 54 else data)


def copy_hash(copy_records: list[dict]) -> str:
    return stable_hash([{key: item.get(key) for key in ("id", "rendered", "authored", "status", "parameters")} for item in copy_records])


def baseline_by_id() -> dict[str, dict]:
    manifest = read_json(BASELINE_MANIFEST, {"scenarios": []})
    return {item["id"]: item for item in manifest.get("scenarios", [])}


def capture_one(udid: str, container: Path, scenario: dict, fingerprint: str) -> dict:
    identifier = scenario["id"]
    run_id = str(uuid.uuid4())
    stage = WORK / "staging" / run_id
    stage.mkdir(parents=True)
    staged_png = stage / f"{identifier}.png"
    launch_and_wait(udid, container, ["-screenbook-scenario", identifier], run_id)
    command(["xcrun", "simctl", "io", udid, "screenshot", "--type=png", str(staged_png)])
    canonicalize_transient_home_indicator(staged_png)
    width, height = png_dimensions(staged_png)
    if width < 1000 or height < 2000 or height <= width:
        raise ScreenbookError(f"Unexpected capture dimensions for {identifier}: {width}x{height}")
    target = CURRENT / "screens" / f"{identifier}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    image_sha = sha256_file(staged_png)
    pixels = pixel_hash(staged_png)
    baseline = baseline_by_id().get(identifier)
    record = dict(scenario)
    record["fingerprint"] = fingerprint
    record["sourceRevision"] = source_revision()
    record["screenshot"] = {
        "path": f"current/screens/{identifier}.png",
        "width": width,
        "height": height,
        "sha256": image_sha,
        "pixelHash": pixels,
    }
    record["copyHash"] = copy_hash(record.get("copy", []))
    if baseline:
        visual_changed = baseline.get("screenshot", {}).get("pixelHash") != pixels
        copy_changed = baseline.get("copyHash") != record["copyHash"]
        record["changeStatus"] = "visual-and-copy" if visual_changed and copy_changed else "visual" if visual_changed else "copy" if copy_changed else "unchanged"
    else:
        record["changeStatus"] = "no-baseline"
    os.replace(staged_png, target)
    shutil.rmtree(stage, ignore_errors=True)
    return record


def finalize_manifest(registry: dict, records: dict[str, dict]) -> dict:
    ordered = [records[item["id"]] for item in registry["scenarios"] if item["id"] in records]
    manifest = {
        "schemaVersion": 1,
        "captureProfile": CAPTURE_PROFILE,
        "sourceRevision": source_revision(),
        "scenarios": ordered,
    }
    manifest["manifestHash"] = stable_hash(manifest)
    write_json_atomic(CURRENT_MANIFEST, manifest)
    return manifest


def selected_scenarios(registry: dict, args) -> list[tuple[dict, str]]:
    current = read_json(CURRENT_MANIFEST, {"scenarios": []})
    previous = {item["id"]: item for item in current.get("scenarios", [])}
    by_id = {item["id"]: item for item in registry["scenarios"]}
    if args.scenario:
        if args.scenario not in by_id:
            raise ScreenbookError(f"Unknown scenario ID: {args.scenario}")
        scenarios = [by_id[args.scenario]]
    elif args.changed:
        scenarios = []
        for scenario in registry["scenarios"]:
            fingerprint = scenario_fingerprint(scenario)
            if previous.get(scenario["id"], {}).get("fingerprint") != fingerprint:
                scenarios.append(scenario)
    else:
        scenarios = registry["scenarios"]
    return [(scenario, scenario_fingerprint(scenario)) for scenario in scenarios]


def capture(args) -> None:
    udid, _app, container, registry = prepare_capture_build()
    selected = selected_scenarios(registry, args)
    print("Capture set:")
    for scenario, _fingerprint in selected:
        print(f"  - {scenario['id']}")
    if not selected:
        print("  (no changed scenarios)")
        build_site()
        return
    current = read_json(CURRENT_MANIFEST, {"scenarios": []})
    records = {item["id"]: item for item in current.get("scenarios", [])}
    failures: list[str] = []
    for scenario, fingerprint in selected:
        identifier = scenario["id"]
        try:
            records[identifier] = capture_one(udid, container, scenario, fingerprint)
            print(f"  PASS {identifier}")
        except Exception as error:
            failures.append(f"{identifier}: {error}")
            print(f"  FAIL {identifier}: {error}")
    finalize_manifest(registry, records)
    build_site()
    if failures:
        raise ScreenbookError("Capture failures preserved prior valid artifacts:\n" + "\n".join(failures))


def list_scenarios(_args=None) -> None:
    _udid, _app, _container, registry = prepare_capture_build()
    for scenario in registry["scenarios"]:
        print(f"{scenario['id']}\t{scenario['title']}")


def build_site(_args=None) -> None:
    manifest = read_json(CURRENT_MANIFEST)
    if not manifest:
        raise ScreenbookError("No current Screenbook manifest. Run capture --all first.")
    baseline = read_json(BASELINE_MANIFEST, {"schemaVersion": 1, "scenarios": []})
    if GENERATED_SITE.exists():
        shutil.rmtree(GENERATED_SITE)
    shutil.copytree(SITE_SOURCE, GENERATED_SITE)
    payload = {"manifest": manifest, "baseline": baseline}
    data = "window.SCREENBOOK_DATA = " + json.dumps(payload, ensure_ascii=False, sort_keys=True) + ";\n"
    (GENERATED_SITE / "data.js").write_text(data, encoding="utf-8")
    print(f"Built local gallery: {GENERATED_SITE / 'index.html'}")


def accept_baseline(args) -> None:
    current = read_json(CURRENT_MANIFEST)
    if not current:
        raise ScreenbookError("No current artifacts to accept.")
    selected = next((item for item in current["scenarios"] if item["id"] == args.scenario), None)
    if not selected:
        raise ScreenbookError(f"Unknown or uncaptured scenario: {args.scenario}")
    baseline = read_json(BASELINE_MANIFEST, {"schemaVersion": 1, "captureProfile": CAPTURE_PROFILE, "scenarios": []})
    records = {item["id"]: item for item in baseline.get("scenarios", [])}
    record = json.loads(json.dumps(selected))
    source = ROOT / "tmp" / "screenbook" / record["screenshot"]["path"]
    target = BASELINE / "screens" / f"{record['id']}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    record["screenshot"]["path"] = f"baseline/screens/{record['id']}.png"
    record["changeStatus"] = "unchanged"
    records[record["id"]] = record
    baseline["scenarios"] = sorted(records.values(), key=lambda item: item["id"])
    baseline["manifestHash"] = stable_hash({key: value for key, value in baseline.items() if key != "manifestHash"})
    write_json_atomic(BASELINE_MANIFEST, baseline)
    build_site()
    print(f"Accepted local baseline: {record['id']}")


def validate_review(review: dict, manifest: dict) -> list[str]:
    errors: list[str] = []
    if review.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1")
    if not isinstance(review.get("items"), list):
        errors.append("items must be an array")
        return errors
    scenario_map = {item["id"]: item for item in manifest.get("scenarios", [])}
    seen: set[str] = set()
    decisions = {"open", "approved", "rejected", "needs-discussion"}
    for index, item in enumerate(review["items"]):
        prefix = f"items[{index}]"
        review_id = item.get("reviewId")
        if not review_id or review_id in seen:
            errors.append(f"{prefix}.reviewId is missing or duplicated")
        seen.add(review_id)
        if item.get("decision") not in decisions:
            errors.append(f"{prefix}.decision is unknown")
        scenario = scenario_map.get(item.get("scenarioId"))
        if not scenario:
            errors.append(f"{prefix}.scenarioId is unknown")
            continue
        copy_id = item.get("copyId")
        if copy_id:
            source = next((copy for copy in scenario.get("copy", []) if copy["id"] == copy_id), None)
            if not source:
                errors.append(f"{prefix}.copyId is unknown")
            elif source.get("status") != "stable" and item.get("decision") == "approved":
                errors.append(f"{prefix} cannot approve a provisional copy mapping")
            elif item.get("sourceRendered") != source.get("rendered"):
                errors.append(f"{prefix} is stale: rendered source changed")
        if item.get("sourceManifestHash") != manifest.get("manifestHash"):
            errors.append(f"{prefix} is stale: manifest hash changed")
    return errors


def validate_review_command(args) -> None:
    manifest = read_json(CURRENT_MANIFEST)
    review = read_json(Path(args.path))
    if not manifest or not review:
        raise ScreenbookError("Current manifest or review document is missing.")
    errors = validate_review(review, manifest)
    if errors:
        raise ScreenbookError("Review validation failed:\n" + "\n".join(f"- {item}" for item in errors))
    print(f"Review export valid: {args.path} ({len(review['items'])} items)")


def verify(_args=None) -> None:
    registry = read_json(REGISTRY_PATH)
    manifest = read_json(CURRENT_MANIFEST)
    if not registry or not manifest:
        raise ScreenbookError("Registry/current manifest missing; run capture --all.")
    validate_registry(registry)
    registered_ids = [item["id"] for item in registry["scenarios"]]
    current_ids = [item["id"] for item in manifest.get("scenarios", [])]
    if current_ids != registered_ids:
        raise ScreenbookError("Current manifest does not contain the complete registry in registry order.")
    for scenario in manifest["scenarios"]:
        image = WORK / scenario["screenshot"]["path"]
        if not image.exists() or png_dimensions(image) != (scenario["screenshot"]["width"], scenario["screenshot"]["height"]):
            raise ScreenbookError(f"Missing or dimension-mismatched screenshot: {scenario['id']}")
        if sha256_file(image) != scenario["screenshot"]["sha256"]:
            raise ScreenbookError(f"Screenshot hash mismatch: {scenario['id']}")
        for dependency in scenario["dependencies"]:
            if not (ROOT / dependency).exists():
                raise ScreenbookError(f"Missing dependency {dependency}")
    for path in (ROOT / "PhoneInTheOtherRoomApp" / "Screenbook").glob("*.swift"):
        if not path.read_text(encoding="utf-8").lstrip().startswith("#if DEBUG"):
            raise ScreenbookError(f"Debug isolation guard missing: {path}")
        if "MVPMockData" in path.read_text(encoding="utf-8"):
            raise ScreenbookError(f"Gated mock dependency found in {path}")
    if not (GENERATED_SITE / "index.html").exists():
        raise ScreenbookError("Generated local site is missing.")
    print(f"Screenbook verify: PASS ({len(current_ids)} scenarios, {manifest['manifestHash'][:12]})")


def serve(args) -> None:
    build_site()
    os.chdir(WORK)
    handler = http.server.SimpleHTTPRequestHandler
    server = http.server.ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    print(f"Screenbook: http://127.0.0.1:{args.port}/site/index.html", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    subcommands = root.add_subparsers(dest="command", required=True)
    subcommands.add_parser("doctor").set_defaults(function=doctor)
    subcommands.add_parser("list").set_defaults(function=list_scenarios)
    capture_parser = subcommands.add_parser("capture")
    selection = capture_parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--scenario")
    selection.add_argument("--changed", action="store_true")
    selection.add_argument("--all", action="store_true")
    capture_parser.set_defaults(function=capture)
    subcommands.add_parser("build-site").set_defaults(function=build_site)
    serve_parser = subcommands.add_parser("serve")
    serve_parser.add_argument("--port", type=int, default=SERVER_PORT)
    serve_parser.set_defaults(function=serve)
    subcommands.add_parser("verify").set_defaults(function=verify)
    baseline_parser = subcommands.add_parser("accept-baseline")
    baseline_parser.add_argument("--scenario", required=True)
    baseline_parser.set_defaults(function=accept_baseline)
    review_parser = subcommands.add_parser("validate-review")
    review_parser.add_argument("path")
    review_parser.set_defaults(function=validate_review_command)
    return root


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        args.function(args)
        return 0
    except ScreenbookError as error:
        print(f"Screenbook error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
