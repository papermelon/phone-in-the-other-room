"""Actual release components, isolated DEBUG fixtures, iPhone SE.

Requires the current simulator app already installed. No live account/service.
Run from the repository root. No temporary app entry hook is needed.
"""
import pathlib
import subprocess
import time

device = "60935BFC-7044-4BE8-9712-7D1B6C568A16"
bundle = "com.ngawangchime.countingsheep"
output = pathlib.Path(__file__).resolve().parent
cases = [
    ("party-mixed-light", "unified-party", ["--buddy-light"]),
    ("party-mixed-dark", "unified-party", []),
    ("party-mixed-light-ax5", "unified-party", ["--buddy-light", "--buddy-max-text"]),
    ("party-mixed-light-ax5-bottom", "unified-party", ["--buddy-light", "--buddy-max-text", "--buddy-bottom"]),
    ("global-eight-dark", "unified", []),
    ("global-eight-light-ax5", "unified", ["--buddy-light", "--buddy-max-text"]),
    ("global-eight-light-ax5-bottom", "unified", ["--buddy-light", "--buddy-max-text", "--buddy-bottom"]),
    ("global-zero-parties-light", "unified-no-party", ["--buddy-light"]),
    ("global-unavailable-dark", "unified-unavailable", []),
    ("global-empty-light", "unified-empty", ["--buddy-light"]),
    ("global-stale-dark", "unified-stale", []),
    ("global-failed-light", "unified-failed", ["--buddy-light"]),
    ("visibility-light", "visibility", ["--buddy-light"]),
    ("visibility-light-ax5", "visibility", ["--buddy-light", "--buddy-max-text"]),
    ("public-card-dark", "public-card", []),
    ("public-card-dark-ax5", "public-card", ["--buddy-max-text"]),
]
for name, mode, args in cases:
    subprocess.run(["xcrun", "simctl", "launch", "--terminate-running-process", device, bundle,
                    "--campfire-buddies-qa", "--buddy-view=" + mode, *args], check=True, stdout=subprocess.DEVNULL)
    time.sleep(5 if name == "party-mixed-light" else 2)
    subprocess.run(["xcrun", "simctl", "io", device, "screenshot", str(output / (name + ".png"))], check=True, capture_output=True)
    print(name, flush=True)
