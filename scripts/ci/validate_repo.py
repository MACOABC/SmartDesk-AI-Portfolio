#!/usr/bin/env python3
"""Deterministic repository validation with redacted secret findings."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - exercised by the CI dependency precheck
    yaml = None


ROOT = Path(__file__).resolve().parents[2]
JSON_EXCLUDES = {".git"}
SECRET_RULES = {
    "private_key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "openai_key": re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b"),
    "github_token": re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b"),
    "telegram_token": re.compile(r"\b\d{8,12}:[A-Za-z0-9_-]{30,}\b"),
}


def tracked_files(root: Path) -> list[Path]:
    try:
        result = subprocess.run(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
            cwd=root,
            check=True,
            capture_output=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return [p for p in root.rglob("*") if p.is_file() and not any(x in p.parts for x in JSON_EXCLUDES)]
    return [root / item.decode("utf-8") for item in result.stdout.split(b"\0") if item]


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return path.name


def validate_json(path: Path, failures: list[str]) -> None:
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(f"invalid_json file={display_path(path)} error={type(exc).__name__}", failures)
        return

    if "n8n" in path.parts and "workflows" in path.parts:
        if not isinstance(data, dict):
            fail(f"invalid_n8n_workflow file={display_path(path)} reason=not_object", failures)
            return
        nodes = data.get("nodes")
        connections = data.get("connections")
        if not isinstance(nodes, list) or not nodes:
            fail(f"invalid_n8n_workflow file={display_path(path)} reason=nodes", failures)
        if not isinstance(connections, dict):
            fail(f"invalid_n8n_workflow file={display_path(path)} reason=connections", failures)
        names = [node.get("name") for node in nodes if isinstance(node, dict)] if isinstance(nodes, list) else []
        if len(names) != len(set(names)):
            fail(f"invalid_n8n_workflow file={display_path(path)} reason=duplicate_node_name", failures)


def validate_yaml(path: Path, failures: list[str]) -> None:
    if yaml is None:
        fail("yaml_validator_dependency_missing package=PyYAML", failures)
        return
    try:
        with path.open("r", encoding="utf-8") as handle:
            yaml.safe_load(handle)
    except (OSError, UnicodeDecodeError, yaml.YAMLError) as exc:
        fail(f"invalid_yaml file={display_path(path)} error={type(exc).__name__}", failures)


def validate_migrations(root: Path, failures: list[str]) -> None:
    migrations = sorted((root / "db" / "migrations").glob("*.sql"))
    numbers: list[int] = []
    for migration in migrations:
        match = re.match(r"^(\d{3})_[a-z0-9_]+\.sql$", migration.name)
        if not match:
            fail(f"invalid_migration_name file={migration.relative_to(root)}", failures)
            continue
        numbers.append(int(match.group(1)))
    if numbers and numbers != list(range(numbers[0], numbers[-1] + 1)):
        fail(f"migration_sequence_has_gap sequence={numbers}", failures)


def validate_compose(root: Path, failures: list[str]) -> None:
    compose_text = (root / "compose.yaml").read_text(encoding="utf-8")
    if re.search(r"^\s*image:\s*\S+:latest\s*$", compose_text, re.MULTILINE):
        fail("compose_uses_latest_tag", failures)
    required_images = ("postgres:", "docker.n8n.io/n8nio/n8n:", "caddy:")
    for image in required_images:
        if image not in compose_text:
            fail(f"compose_missing_image prefix={image}", failures)


def scan_secrets(files: list[Path], root: Path, failures: list[str]) -> None:
    binary_suffixes = {".pbit", ".pbix", ".png", ".jpg", ".jpeg", ".gif", ".pdf"}
    for path in files:
        if path.suffix.lower() in binary_suffixes:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for rule_name, pattern in SECRET_RULES.items():
            match = pattern.search(text)
            if match:
                line = text.count("\n", 0, match.start()) + 1
                fail(f"possible_secret file={path.relative_to(root)} line={line} rule={rule_name}", failures)


def ensure_forbidden_files_absent(files: list[Path], root: Path, failures: list[str]) -> None:
    tracked = {path.relative_to(root).as_posix() for path in files}
    forbidden = {".env", "powerbi/SmartDeskAI.pbix", "powerbi/SmartDeskAI.pbit.pbix"}
    for item in sorted(forbidden & tracked):
        fail(f"forbidden_tracked_file file={item}", failures)
    dump_suffixes = {".dump", ".pgdump", ".backup", ".cms", ".key", ".pfx", ".p12"}
    for item in sorted(tracked):
        if Path(item).suffix.lower() in dump_suffixes:
            fail(f"forbidden_tracked_artifact file={item}", failures)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json-file", type=Path, help="validate one JSON file (used by the controlled negative test)")
    args = parser.parse_args()
    failures: list[str] = []
    if args.json_file:
        validate_json(args.json_file.resolve(), failures)
    else:
        files = tracked_files(ROOT)
        ensure_forbidden_files_absent(files, ROOT, failures)
        scan_secrets(files, ROOT, failures)
        validate_migrations(ROOT, failures)
        validate_compose(ROOT, failures)
        for path in files:
            if path.suffix.lower() == ".json":
                validate_json(path, failures)
            elif path.suffix.lower() in {".yaml", ".yml"}:
                validate_yaml(path, failures)

    if failures:
        for message in failures:
            print(f"FAIL {message}", file=sys.stderr)
        print(f"repository_validation=FAIL failures={len(failures)}", file=sys.stderr)
        return 1
    print("repository_validation=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
