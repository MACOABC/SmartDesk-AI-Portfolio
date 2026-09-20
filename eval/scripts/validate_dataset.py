#!/usr/bin/env python3
"""Validate the versioned SmartDesk AI evaluation dataset using stdlib only."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import unicodedata
from collections import Counter
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DATASET_DIR = REPO_ROOT / "eval" / "datasets" / "v1"
EVAL_SCHEMA_PATH = REPO_ROOT / "eval" / "schemas" / "evaluation-case.schema.json"
PRODUCTION_SCHEMA_PATH = REPO_ROOT / "prompts" / "ticket-classification" / "schema-v2.json"
EXPECTED_COUNTS = {"dev": 30, "test": 120}
SIMILARITY_LIMIT = 0.88


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalized_text(case: dict[str, Any]) -> str:
    joined = " ".join(str(case.get(field, "")) for field in ("area", "title", "description"))
    normalized = unicodedata.normalize("NFKC", joined).casefold()
    normalized = re.sub(r"[^\w]+", " ", normalized, flags=re.UNICODE)
    return " ".join(normalized.split())


def validate_value(value: Any, schema: dict[str, Any], location: str, errors: list[str]) -> None:
    expected_type = schema.get("type")
    if expected_type == "object":
        if not isinstance(value, dict):
            errors.append(f"{location}: expected object")
            return
        required = schema.get("required", [])
        for key in required:
            if key not in value:
                errors.append(f"{location}: missing required field {key!r}")
        if schema.get("additionalProperties") is False:
            extras = sorted(set(value) - set(schema.get("properties", {})))
            if extras:
                errors.append(f"{location}: unexpected fields {extras}")
        for key, child_schema in schema.get("properties", {}).items():
            if key in value:
                validate_value(value[key], child_schema, f"{location}.{key}", errors)
        return

    if expected_type == "string" and not isinstance(value, str):
        errors.append(f"{location}: expected string")
        return
    if expected_type == "string":
        if len(value) < schema.get("minLength", 0):
            errors.append(f"{location}: shorter than minLength")
        if len(value) > schema.get("maxLength", sys.maxsize):
            errors.append(f"{location}: longer than maxLength")
        if "pattern" in schema and re.fullmatch(schema["pattern"], value) is None:
            errors.append(f"{location}: does not match {schema['pattern']!r}")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{location}: {value!r} is not in {schema['enum']}")


def read_json(path: Path, errors: list[str]) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"{path}: cannot load JSON: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{path}: top-level JSON must be an object")
        return {}
    return value


def read_jsonl(path: Path, split: str, schema: dict[str, Any], errors: list[str]) -> list[dict[str, Any]]:
    cases: list[dict[str, Any]] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        errors.append(f"{path}: cannot read: {exc}")
        return cases

    for line_number, line in enumerate(lines, start=1):
        location = f"{path.name}:{line_number}"
        if not line.strip():
            errors.append(f"{location}: blank lines are not allowed")
            continue
        try:
            case = json.loads(line)
        except json.JSONDecodeError as exc:
            errors.append(f"{location}: malformed JSON: {exc.msg}")
            continue
        validate_value(case, schema, location, errors)
        if not isinstance(case, dict):
            continue
        if case.get("split") != split:
            errors.append(f"{location}: split must be {split!r}")
        expected_prefix = f"SD-EVAL-{split.upper()}-"
        if not str(case.get("id", "")).startswith(expected_prefix):
            errors.append(f"{location}: id must start with {expected_prefix!r}")
        for field in ("area", "title", "description", "ground_truth_notes"):
            value = case.get(field)
            if isinstance(value, str) and value != value.strip():
                errors.append(f"{location}.{field}: leading/trailing whitespace is not allowed")
        cases.append(case)
    return cases


def distribution(cases: list[dict[str, Any]], field: str) -> dict[str, int]:
    return dict(sorted(Counter(str(case.get(field)) for case in cases).items()))


def validate_manifest(
    manifest: dict[str, Any],
    dataset_dir: Path,
    cases_by_split: dict[str, list[dict[str, Any]]],
    production_schema: dict[str, Any],
    errors: list[str],
) -> None:
    required = {
        "dataset_version",
        "status",
        "created_at",
        "labeling_policy_version",
        "based_on_commit",
        "production_contract",
        "frozen_test",
        "files",
        "totals",
        "distributions",
    }
    missing = sorted(required - set(manifest))
    if missing:
        errors.append(f"manifest: missing fields {missing}")
    if manifest.get("dataset_version") != "1.0.0":
        errors.append("manifest.dataset_version must be '1.0.0'")
    if manifest.get("status") != "frozen":
        errors.append("manifest.status must be 'frozen'")
    if manifest.get("labeling_policy_version") != "labeling-policy-v1":
        errors.append("manifest.labeling_policy_version must be 'labeling-policy-v1'")
    if manifest.get("frozen_test") is not True:
        errors.append("manifest.frozen_test must be true")

    contract = manifest.get("production_contract", {})
    expected_contract = {
        "prompt_version": "ticket-classification-v2",
        "schema_version": production_schema.get("$id"),
        "provider": "openai",
        "model": "gpt-5.6-luna",
    }
    if contract != expected_contract:
        errors.append(f"manifest.production_contract must equal {expected_contract}")

    files = manifest.get("files", {})
    totals = manifest.get("totals", {})
    manifest_distributions = manifest.get("distributions", {})
    for split, cases in cases_by_split.items():
        expected_file = dataset_dir / f"{split}.jsonl"
        file_entry = files.get(split, {}) if isinstance(files, dict) else {}
        if file_entry.get("path") != f"{split}.jsonl":
            errors.append(f"manifest.files.{split}.path must be {split}.jsonl")
        if expected_file.exists() and file_entry.get("sha256") != sha256_file(expected_file):
            errors.append(f"manifest.files.{split}.sha256 does not match file content")
        if file_entry.get("records") != len(cases):
            errors.append(f"manifest.files.{split}.records does not match parsed records")
        if totals.get(split) != len(cases):
            errors.append(f"manifest.totals.{split} does not match parsed records")
        for field in ("expected_category", "expected_priority", "difficulty", "scenario_type"):
            actual = distribution(cases, field)
            declared = manifest_distributions.get(split, {}).get(field)
            if declared != actual:
                errors.append(f"manifest.distributions.{split}.{field} does not match dataset")
    if totals.get("all") != sum(len(cases) for cases in cases_by_split.values()):
        errors.append("manifest.totals.all does not match parsed records")


def validate_dataset(dataset_dir: Path, manifest_path: Path | None = None) -> tuple[list[str], dict[str, Any]]:
    errors: list[str] = []
    eval_schema = read_json(EVAL_SCHEMA_PATH, errors)
    production_schema = read_json(PRODUCTION_SCHEMA_PATH, errors)

    eval_categories = eval_schema.get("properties", {}).get("expected_category", {}).get("enum")
    eval_priorities = eval_schema.get("properties", {}).get("expected_priority", {}).get("enum")
    prod_categories = production_schema.get("properties", {}).get("category", {}).get("enum")
    prod_priorities = production_schema.get("properties", {}).get("priority", {}).get("enum")
    if eval_categories != prod_categories:
        errors.append("evaluation category enum differs from production schema-v2")
    if eval_priorities != prod_priorities:
        errors.append("evaluation priority enum differs from production schema-v2")

    cases_by_split = {
        split: read_jsonl(dataset_dir / f"{split}.jsonl", split, eval_schema, errors)
        for split in ("dev", "test")
    }
    all_cases = cases_by_split["dev"] + cases_by_split["test"]

    for split, expected_count in EXPECTED_COUNTS.items():
        actual_count = len(cases_by_split[split])
        if actual_count != expected_count:
            errors.append(f"{split}: expected {expected_count} records, found {actual_count}")
        expected_ids = [f"SD-EVAL-{split.upper()}-{index:03d}" for index in range(1, expected_count + 1)]
        actual_ids = [str(case.get("id", "")) for case in cases_by_split[split]]
        if actual_ids != expected_ids:
            errors.append(f"{split}: IDs must be ordered and contiguous from 001 to {expected_count:03d}")

    ids = [str(case.get("id", "")) for case in all_cases]
    duplicate_ids = sorted(identifier for identifier, count in Counter(ids).items() if count > 1)
    if duplicate_ids:
        errors.append(f"duplicate IDs: {duplicate_ids}")

    normalized_cases = [(str(case.get("id", "")), normalized_text(case)) for case in all_cases]
    duplicate_content = sorted(text for text, count in Counter(text for _, text in normalized_cases).items() if count > 1)
    if duplicate_content:
        errors.append(f"duplicate normalized ticket content found ({len(duplicate_content)} groups)")

    tokenized_cases = [(identifier, set(text.split())) for identifier, text in normalized_cases]
    for index, (left_id, left_tokens) in enumerate(tokenized_cases):
        if len(left_tokens) < 6:
            continue
        for right_id, right_tokens in tokenized_cases[index + 1 :]:
            if len(right_tokens) < 6:
                continue
            ratio = len(left_tokens & right_tokens) / len(left_tokens | right_tokens)
            if ratio >= SIMILARITY_LIMIT:
                errors.append(
                    f"excessive token similarity {ratio:.3f} between {left_id} and {right_id} "
                    f"(limit {SIMILARITY_LIMIT:.2f})"
                )

    test_categories = distribution(cases_by_split["test"], "expected_category")
    expected_test_categories = {category: 20 for category in (prod_categories or [])}
    if test_categories != expected_test_categories:
        errors.append(f"test category distribution must be {expected_test_categories}, got {test_categories}")

    resolved_manifest = manifest_path or dataset_dir / "dataset-manifest.json"
    manifest = read_json(resolved_manifest, errors)
    validate_manifest(manifest, dataset_dir, cases_by_split, production_schema, errors)

    summary = {
        "records": {split: len(cases) for split, cases in cases_by_split.items()},
        "distributions": {
            split: {
                field: distribution(cases, field)
                for field in ("expected_category", "expected_priority", "difficulty", "scenario_type")
            }
            for split, cases in cases_by_split.items()
        },
    }
    return errors, summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset-dir", type=Path, default=DEFAULT_DATASET_DIR)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()

    errors, summary = validate_dataset(args.dataset_dir.resolve(), args.manifest)
    if errors:
        print(f"FAIL: dataset validation found {len(errors)} error(s)", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("PASS: SmartDesk AI evaluation dataset is valid")
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
