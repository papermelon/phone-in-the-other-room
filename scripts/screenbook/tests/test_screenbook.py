import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "screenbook.py"
SPEC = importlib.util.spec_from_file_location("screenbook", MODULE_PATH)
screenbook = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(screenbook)


def scenario(identifier, status="stable"):
    return {
        "id": identifier,
        "title": identifier,
        "fixtureVersion": 1,
        "copy": [{
            "id": f"{identifier}.title",
            "rendered": "Warm copy",
            "authored": "Warm copy",
            "status": status,
            "parameters": {},
        }],
    }


class ScreenbookTests(unittest.TestCase):
    def setUp(self):
        self.scenarios = [scenario(identifier) for identifier in sorted(screenbook.EXPECTED_SCENARIO_IDS)]
        self.registry = {
            "schemaVersion": 1,
            "captureProfile": screenbook.CAPTURE_PROFILE,
            "scenarios": self.scenarios,
        }
        self.manifest = {
            "schemaVersion": 1,
            "captureProfile": screenbook.CAPTURE_PROFILE,
            "manifestHash": "a" * 64,
            "scenarios": self.scenarios,
        }

    def test_registry_requires_the_nine_stable_unique_ids(self):
        screenbook.validate_registry(self.registry)
        duplicate = json.loads(json.dumps(self.registry))
        duplicate["scenarios"][4]["id"] = duplicate["scenarios"][0]["id"]
        with self.assertRaises(screenbook.ScreenbookError):
            screenbook.validate_registry(duplicate)

        missing = json.loads(json.dumps(self.registry))
        missing["scenarios"].pop()
        with self.assertRaises(screenbook.ScreenbookError):
            screenbook.validate_registry(missing)

        unexpected = json.loads(json.dumps(self.registry))
        unexpected["scenarios"][-1]["id"] = "iphone.test.unapproved.default"
        with self.assertRaises(screenbook.ScreenbookError):
            screenbook.validate_registry(unexpected)

    def test_review_round_trip_accepts_current_stable_copy(self):
        item = self.scenarios[0]["copy"][0]
        review = {
            "schemaVersion": 1,
            "items": [{
                "reviewId": "review-1",
                "scenarioId": self.scenarios[0]["id"],
                "copyId": item["id"],
                "sourceRendered": item["rendered"],
                "decision": "approved",
                "sourceManifestHash": self.manifest["manifestHash"],
            }],
        }
        self.assertEqual(screenbook.validate_review(review, self.manifest), [])

    def test_review_blocks_stale_and_provisional_approval(self):
        provisional = scenario("iphone.test.provisional.default", "provisional")
        self.manifest["scenarios"].append(provisional)
        review = {
            "schemaVersion": 1,
            "items": [{
                "reviewId": "review-2",
                "scenarioId": provisional["id"],
                "copyId": provisional["copy"][0]["id"],
                "sourceRendered": "Old copy",
                "decision": "approved",
                "sourceManifestHash": "b" * 64,
            }],
        }
        errors = screenbook.validate_review(review, self.manifest)
        self.assertTrue(any("provisional" in error for error in errors))
        self.assertTrue(any("stale" in error for error in errors))

    def test_png_dimensions_reads_ihdr(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "screen.png"
            path.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" + (1206).to_bytes(4, "big") + (2622).to_bytes(4, "big"))
            self.assertEqual(screenbook.png_dimensions(path), (1206, 2622))

    def test_home_indicator_canonicalization_removes_only_transient_band(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / f"capture-{index}.png" for index in range(2)]
            width, height = 8, 96
            originals = []
            for variant, path in enumerate(paths):
                pixels = bytearray([40, 50, 60, 255] * width * height)
                for y in range(height - 40, height - 24):
                    for x in range(2, 6):
                        offset = (y * width + x) * 4
                        pixels[offset:offset + 4] = bytes([100 + variant * 80, 100, 100, 255])
                originals.append(bytes(pixels))
                screenbook.write_rgba_png(path, width, height, pixels)
                screenbook.canonicalize_transient_home_indicator(path)
            decoded = [screenbook.decode_rgba_png(path)[2] for path in paths]
            self.assertEqual(decoded[0], decoded[1])
            self.assertEqual(decoded[0][: (height - 44) * width * 4], originals[0][: (height - 44) * width * 4])

    def test_manifest_hash_is_key_order_independent(self):
        self.assertEqual(screenbook.stable_hash({"a": 1, "b": 2}), screenbook.stable_hash({"b": 2, "a": 1}))

    def test_schemas_are_valid_json_and_versioned(self):
        schema_dir = Path(__file__).resolve().parents[1] / "schema"
        for path in schema_dir.glob("*.json"):
            schema = json.loads(path.read_text())
            self.assertEqual(schema["properties"]["schemaVersion"]["const"], 1)
            if path.name == "scenario-manifest.schema.json":
                scenarios = schema["properties"]["scenarios"]
                self.assertEqual(scenarios["minItems"], len(screenbook.EXPECTED_SCENARIO_IDS))
                self.assertEqual(scenarios["maxItems"], len(screenbook.EXPECTED_SCENARIO_IDS))


if __name__ == "__main__":
    unittest.main()
