from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE_DATASET = REPO_ROOT / "eval" / "datasets" / "v1"
VALIDATOR = REPO_ROOT / "eval" / "scripts" / "validate_dataset.py"


class DatasetValidatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.dataset_dir = Path(self.temp_dir.name) / "v1"
        shutil.copytree(SOURCE_DATASET, self.dataset_dir)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def run_validator(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(VALIDATOR), "--dataset-dir", str(self.dataset_dir)],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def load_lines(self, split: str = "dev") -> list[dict[str, object]]:
        path = self.dataset_dir / f"{split}.jsonl"
        return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]

    def write_lines(self, records: list[dict[str, object]], split: str = "dev") -> None:
        path = self.dataset_dir / f"{split}.jsonl"
        content = "\n".join(json.dumps(record, ensure_ascii=False, separators=(",", ":")) for record in records) + "\n"
        path.write_text(content, encoding="utf-8")

    def assert_invalid_with(self, expected_fragment: str) -> None:
        result = self.run_validator()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(expected_fragment, result.stderr)

    def test_valid_frozen_dataset_passes(self) -> None:
        result = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS", result.stdout)

    def test_duplicate_id_is_rejected(self) -> None:
        records = self.load_lines()
        records[1]["id"] = records[0]["id"]
        self.write_lines(records)
        self.assert_invalid_with("duplicate IDs")

    def test_invalid_category_is_rejected(self) -> None:
        records = self.load_lines()
        records[0]["expected_category"] = "security"
        self.write_lines(records)
        self.assert_invalid_with("is not in")

    def test_invalid_priority_is_rejected(self) -> None:
        records = self.load_lines()
        records[0]["expected_priority"] = "urgent"
        self.write_lines(records)
        self.assert_invalid_with("is not in")

    def test_malformed_jsonl_is_rejected(self) -> None:
        path = self.dataset_dir / "dev.jsonl"
        lines = path.read_text(encoding="utf-8").splitlines()
        lines[0] = '{"id":'
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        self.assert_invalid_with("malformed JSON")

    def test_manifest_hash_mismatch_is_rejected(self) -> None:
        path = self.dataset_dir / "dataset-manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        manifest["files"]["test"]["sha256"] = "0" * 64
        path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        self.assert_invalid_with("sha256 does not match")


if __name__ == "__main__":
    unittest.main()
