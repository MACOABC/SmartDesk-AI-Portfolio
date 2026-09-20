#!/usr/bin/env python3
"""Run a guarded SmartDesk AI evaluation against the production contract."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import platform
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from dataclasses import dataclass
from datetime import date, datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Callable


REPO_ROOT = Path(__file__).resolve().parents[2]
PROMPT_PATH = REPO_ROOT / "prompts" / "ticket-classification" / "v2.md"
PRODUCTION_SCHEMA_PATH = REPO_ROOT / "prompts" / "ticket-classification" / "schema-v2.json"
DEFAULT_RUNS_DIR = REPO_ROOT / "eval" / "runs"
ENDPOINT = "https://api.openai.com/v1/responses"
PROVIDER = "openai"
REQUESTED_MODEL = "gpt-5.6-luna"
PROMPT_VERSION = "ticket-classification-v2"
SCHEMA_VERSION = "ticket-classification-schema-v2"
MAX_OUTPUT_TOKENS = 450
REQUEST_TIMEOUT_SECONDS = 60
MAX_ATTEMPTS = 3
BACKOFF_SECONDS = (0, 2, 4)
TRANSIENT_HTTP_STATUSES = {408, 425, 429, 500, 502, 503, 504}
HITL_THRESHOLD = 0.75
FROZEN_TEST_SHA256 = "461a27c60c2c9d6f971e54a2fadc54dedd84f19f53f557ed3560735508ad76f6"


class EvaluationFailure(Exception):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


class TransientTransportFailure(Exception):
    pass


@dataclass(frozen=True)
class Pricing:
    input_per_million_usd: Decimal
    cached_input_per_million_usd: Decimal
    cache_write_per_million_usd: Decimal
    output_per_million_usd: Decimal
    source: str
    verification_date: str


@dataclass(frozen=True)
class Limits:
    max_cases: int
    max_api_calls: int
    max_cost_usd: Decimal


@dataclass(frozen=True)
class Contract:
    prompt: str
    schema: dict[str, Any]
    categories: list[str]
    priorities: list[str]
    prompt_sha256: str
    schema_sha256: str


@dataclass(frozen=True)
class HttpResult:
    status_code: int
    body: dict[str, Any] | None


class CallBudget:
    def __init__(self, limits: Limits):
        self.limits = limits
        self.api_calls = 0
        self.conservative_reserved_usd = Decimal("0")

    def reserve(self, upper_cost_usd: Decimal) -> None:
        if self.api_calls >= self.limits.max_api_calls:
            raise EvaluationFailure("EVAL_MAX_API_CALLS_REACHED")
        if self.conservative_reserved_usd + upper_cost_usd > self.limits.max_cost_usd:
            raise EvaluationFailure("EVAL_MAX_COST_REACHED")
        self.api_calls += 1
        self.conservative_reserved_usd += upper_cost_usd


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def write_json(path: Path, value: dict[str, Any]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def append_jsonl(path: Path, value: dict[str, Any]) -> None:
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n")
        handle.flush()
        os.fsync(handle.fileno())


def load_contract() -> Contract:
    prompt = PROMPT_PATH.read_text(encoding="utf-8")
    schema = json.loads(PRODUCTION_SCHEMA_PATH.read_text(encoding="utf-8"))
    if PROMPT_VERSION not in prompt:
        raise EvaluationFailure("AI_CONTRACT_LOAD_ERROR")
    if (
        schema.get("$id") != SCHEMA_VERSION
        or schema.get("type") != "object"
        or schema.get("additionalProperties") is not False
    ):
        raise EvaluationFailure("AI_CONTRACT_LOAD_ERROR")
    expected_fields = {"category", "priority", "summary", "confidence", "review_required", "review_reason"}
    if set(schema.get("required", [])) != expected_fields or set(schema.get("properties", {})) != expected_fields:
        raise EvaluationFailure("AI_CONTRACT_LOAD_ERROR")
    categories = schema["properties"]["category"].get("enum")
    priorities = schema["properties"]["priority"].get("enum")
    if not isinstance(categories, list) or not isinstance(priorities, list):
        raise EvaluationFailure("AI_CONTRACT_LOAD_ERROR")
    properties = schema["properties"]
    if properties["summary"] != {"type": "string", "minLength": 1, "maxLength": 300}:
        raise EvaluationFailure("AI_CONTRACT_LOAD_ERROR")
    if properties["confidence"] != {"type": "number", "minimum": 0, "maximum": 1}:
        raise EvaluationFailure("AI_CONTRACT_LOAD_ERROR")
    if properties["review_required"] != {"type": "boolean"}:
        raise EvaluationFailure("AI_CONTRACT_LOAD_ERROR")
    review_reason = properties["review_reason"]
    if (
        set(review_reason.get("type", [])) != {"string", "null"}
        or review_reason.get("minLength") != 1
        or review_reason.get("maxLength") != 500
    ):
        raise EvaluationFailure("AI_CONTRACT_LOAD_ERROR")
    return Contract(
        prompt=prompt,
        schema=schema,
        categories=list(categories),
        priorities=list(priorities),
        prompt_sha256=sha256_file(PROMPT_PATH),
        schema_sha256=sha256_file(PRODUCTION_SCHEMA_PATH),
    )


def load_cases(path: Path) -> list[dict[str, Any]]:
    cases: list[dict[str, Any]] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            raise ValueError(f"{path}:{line_number}: blank line")
        case = json.loads(line)
        if not isinstance(case, dict):
            raise ValueError(f"{path}:{line_number}: case must be an object")
        cases.append(case)
    return cases


def validate_versioned_dataset(dataset_path: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    from validate_dataset import validate_dataset

    manifest_path = dataset_path.parent / "dataset-manifest.json"
    frozen_test_path = dataset_path.parent / "test.jsonl"
    if not frozen_test_path.is_file() or sha256_file(frozen_test_path) != FROZEN_TEST_SHA256:
        raise ValueError("Frozen test SHA-256 differs from the approved value")
    errors, _ = validate_dataset(dataset_path.parent, manifest_path)
    if errors:
        raise ValueError("Dataset validation failed: " + "; ".join(errors))
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    matching = [entry for entry in manifest["files"].values() if entry.get("path") == dataset_path.name]
    if len(matching) != 1:
        raise ValueError("Dataset file is not declared exactly once in dataset-manifest.json")
    actual_hash = sha256_file(dataset_path)
    if matching[0].get("sha256") != actual_hash:
        raise ValueError("Dataset SHA-256 differs from its manifest")
    return manifest, load_cases(dataset_path)


def build_ticket_text(case: dict[str, Any]) -> str:
    return "\n".join(
        [
            "<untrusted_ticket_data>",
            "AREA:",
            str(case["area"]),
            "",
            "TITLE:",
            str(case["title"]),
            "",
            "DESCRIPTION:",
            str(case["description"]),
            "</untrusted_ticket_data>",
        ]
    )


def build_request_body(case: dict[str, Any], contract: Contract) -> dict[str, Any]:
    return {
        "model": REQUESTED_MODEL,
        "instructions": contract.prompt,
        "input": [
            {
                "role": "user",
                "content": [{"type": "input_text", "text": build_ticket_text(case)}],
            }
        ],
        "text": {
            "format": {
                "type": "json_schema",
                "name": SCHEMA_VERSION,
                "schema": contract.schema,
                "strict": True,
            }
        },
        "reasoning": {"effort": "none"},
        "store": False,
        "max_output_tokens": MAX_OUTPUT_TOKENS,
    }


def validate_classification_response(response: dict[str, Any], contract: Contract) -> dict[str, Any]:
    if response.get("status") != "completed" or response.get("error") is not None:
        raise EvaluationFailure("AI_PROVIDER_PERMANENT")
    output_texts: list[str] = []
    for item in response.get("output", []) if isinstance(response.get("output"), list) else []:
        if item.get("type") != "message" or not isinstance(item.get("content"), list):
            continue
        for part in item["content"]:
            if part.get("type") == "output_text" and isinstance(part.get("text"), str):
                output_texts.append(part["text"])
    if len(output_texts) != 1 or not output_texts[0]:
        raise EvaluationFailure("AI_RESPONSE_INVALID")
    try:
        candidate = json.loads(output_texts[0])
    except json.JSONDecodeError as exc:
        raise EvaluationFailure("AI_RESPONSE_INVALID") from exc
    expected_keys = {"category", "priority", "summary", "confidence", "review_required", "review_reason"}
    if not isinstance(candidate, dict) or set(candidate) != expected_keys:
        raise EvaluationFailure("AI_RESPONSE_INVALID")
    if candidate["category"] not in contract.categories or candidate["priority"] not in contract.priorities:
        raise EvaluationFailure("AI_RESPONSE_INVALID")
    summary = candidate["summary"]
    if not isinstance(summary, str) or not 1 <= len(summary.strip()) <= 300:
        raise EvaluationFailure("AI_RESPONSE_INVALID")
    confidence = candidate["confidence"]
    if isinstance(confidence, bool) or not isinstance(confidence, (int, float)) or not math.isfinite(confidence):
        raise EvaluationFailure("AI_RESPONSE_INVALID")
    if not 0 <= confidence <= 1:
        raise EvaluationFailure("AI_RESPONSE_INVALID")
    required = confidence < HITL_THRESHOLD
    if not isinstance(candidate["review_required"], bool) or candidate["review_required"] != required:
        raise EvaluationFailure("AI_RESPONSE_INVALID")
    reason = candidate["review_reason"]
    if required:
        if not isinstance(reason, str) or len(reason.strip()) < 1 or len(reason) > 500:
            raise EvaluationFailure("AI_RESPONSE_INVALID")
        reason = reason.strip()
    elif reason is not None:
        raise EvaluationFailure("AI_RESPONSE_INVALID")
    return {
        "category": candidate["category"],
        "priority": candidate["priority"],
        "summary": summary.strip(),
        "confidence": float(confidence),
        "review_required": required,
        "review_reason": reason,
    }


def empty_usage(status: str) -> dict[str, Any]:
    return {
        "usage_accounting_status": status,
        "input_tokens": None,
        "regular_input_tokens": None,
        "cached_tokens": None,
        "cache_write_tokens": None,
        "output_tokens": None,
        "total_tokens": None,
    }


def extract_usage(response: dict[str, Any] | None) -> dict[str, Any]:
    if not isinstance(response, dict) or not isinstance(response.get("usage"), dict):
        return empty_usage("not_reported")
    usage = response["usage"]
    values = (usage.get("input_tokens"), usage.get("output_tokens"), usage.get("total_tokens"))
    if any(isinstance(value, bool) or not isinstance(value, int) or value < 0 for value in values):
        return empty_usage("invalid")
    if usage["total_tokens"] != usage["input_tokens"] + usage["output_tokens"]:
        result = empty_usage("invalid")
        result.update(
            input_tokens=usage["input_tokens"],
            output_tokens=usage["output_tokens"],
            total_tokens=usage["total_tokens"],
        )
        return result
    details = usage.get("input_tokens_details")
    if not isinstance(details, dict) or "cached_tokens" not in details:
        result = empty_usage("cached_tokens_not_reported")
        result.update(
            input_tokens=usage["input_tokens"],
            output_tokens=usage["output_tokens"],
            total_tokens=usage["total_tokens"],
        )
        return result
    cached = details["cached_tokens"]
    if isinstance(cached, bool) or not isinstance(cached, int) or cached < 0 or cached > usage["input_tokens"]:
        result = empty_usage("invalid")
        result.update(
            input_tokens=usage["input_tokens"],
            cached_tokens=cached,
            output_tokens=usage["output_tokens"],
            total_tokens=usage["total_tokens"],
        )
        return result
    cache_write = details.get("cache_write_tokens")
    if "cache_write_tokens" not in details:
        return {
            "usage_accounting_status": "cache_write_tokens_not_reported",
            "input_tokens": usage["input_tokens"],
            "regular_input_tokens": None,
            "cached_tokens": cached,
            "cache_write_tokens": None,
            "output_tokens": usage["output_tokens"],
            "total_tokens": usage["total_tokens"],
        }
    if isinstance(cache_write, bool) or not isinstance(cache_write, int) or cache_write < 0:
        result = empty_usage("invalid")
        result.update(
            input_tokens=usage["input_tokens"],
            cached_tokens=cached,
            cache_write_tokens=cache_write,
            output_tokens=usage["output_tokens"],
            total_tokens=usage["total_tokens"],
        )
        return result
    regular = usage["input_tokens"] - cached - cache_write
    if regular < 0:
        result = empty_usage("invalid")
        result.update(
            input_tokens=usage["input_tokens"],
            cached_tokens=cached,
            cache_write_tokens=cache_write,
            output_tokens=usage["output_tokens"],
            total_tokens=usage["total_tokens"],
        )
        return result
    return {
        "usage_accounting_status": "complete",
        "input_tokens": usage["input_tokens"],
        "regular_input_tokens": regular,
        "cached_tokens": cached,
        "cache_write_tokens": cache_write,
        "output_tokens": usage["output_tokens"],
        "total_tokens": usage["total_tokens"],
    }


def usage_cost(usage: dict[str, Any], pricing: Pricing) -> Decimal | None:
    if usage.get("usage_accounting_status") != "complete":
        return None
    return (
        Decimal(usage["regular_input_tokens"]) * pricing.input_per_million_usd
        + Decimal(usage["cached_tokens"]) * pricing.cached_input_per_million_usd
        + Decimal(usage["cache_write_tokens"]) * pricing.cache_write_per_million_usd
        + Decimal(usage["output_tokens"]) * pricing.output_per_million_usd
    ) / Decimal(1_000_000)


def request_upper_bound(body: dict[str, Any], pricing: Pricing) -> tuple[int, Decimal]:
    # One token cannot encode less than one byte; adding 512 tokens covers
    # transport/message framing absent from the serialized request body.
    input_token_upper_bound = len(canonical_json(body).encode("utf-8")) + 512
    conservative_input_price = max(pricing.input_per_million_usd, pricing.cache_write_per_million_usd)
    cost = (
        Decimal(input_token_upper_bound) * conservative_input_price
        + Decimal(MAX_OUTPUT_TOKENS) * pricing.output_per_million_usd
    ) / Decimal(1_000_000)
    return input_token_upper_bound, cost


def build_preflight(cases: list[dict[str, Any]], contract: Contract, pricing: Pricing, limits: Limits) -> dict[str, Any]:
    if limits.max_cases < 1 or limits.max_api_calls < 1 or limits.max_cost_usd <= 0:
        raise ValueError("All guardrails must be explicit positive values")
    selected = cases[: limits.max_cases]
    if not selected:
        raise ValueError("No cases selected")
    if limits.max_api_calls < len(selected):
        raise ValueError("max_api_calls must allow at least one call per selected case")
    per_call: list[tuple[int, Decimal]] = [request_upper_bound(build_request_body(case, contract), pricing) for case in selected]
    possible_calls = [entry for entry in per_call for _ in range(MAX_ATTEMPTS)]
    used_for_estimate = sorted(possible_calls, key=lambda entry: entry[1], reverse=True)[: limits.max_api_calls]
    estimated_max_cost = sum((entry[1] for entry in used_for_estimate), Decimal("0"))
    if estimated_max_cost > limits.max_cost_usd:
        raise ValueError(
            f"Conservative preflight ${estimated_max_cost} exceeds max_cost_usd ${limits.max_cost_usd}"
        )
    return {
        "method": "UTF-8 request bytes + 512 framing tokens, 450 output tokens, maximum of regular-input/cache-write price, bounded by max_api_calls",
        "selected_cases": len(selected),
        "maximum_possible_attempts": len(selected) * MAX_ATTEMPTS,
        "calls_in_cost_upper_bound": len(used_for_estimate),
        "input_token_upper_bound_min": min(entry[0] for entry in per_call),
        "input_token_upper_bound_max": max(entry[0] for entry in per_call),
        "estimated_max_cost_usd": float(estimated_max_cost),
        "approved_max_cost_usd": float(limits.max_cost_usd),
    }


class OpenAIClient:
    def __init__(self, api_key: str):
        self.api_key = api_key

    def send(self, body: dict[str, Any], timeout_seconds: int) -> HttpResult:
        request = urllib.request.Request(
            ENDPOINT,
            data=canonical_json(body).encode("utf-8"),
            headers={"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
                raw = response.read()
                try:
                    parsed = json.loads(raw.decode("utf-8"))
                except (UnicodeDecodeError, json.JSONDecodeError):
                    parsed = None
                return HttpResult(status_code=response.status, body=parsed if isinstance(parsed, dict) else None)
        except urllib.error.HTTPError as exc:
            return HttpResult(status_code=exc.code, body=None)
        except (urllib.error.URLError, TimeoutError, socket.timeout, OSError) as exc:
            raise TransientTransportFailure from exc


def evaluate_case(
    case: dict[str, Any],
    run_id: str,
    contract: Contract,
    pricing: Pricing,
    budget: CallBudget,
    send_request: Callable[[dict[str, Any], int], HttpResult],
    sleep: Callable[[float], None] = time.sleep,
    clock_ns: Callable[[], int] = time.perf_counter_ns,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    request_body = build_request_body(case, contract)
    _, call_upper_cost = request_upper_bound(request_body, pricing)
    case_started_at = utc_now()
    case_start_ns = clock_ns()
    attempts: list[dict[str, Any]] = []
    classification: dict[str, Any] | None = None
    final_error: str | None = None
    retry_exhausted = False
    returned_model: str | None = None
    response_id: str | None = None

    for attempt_number in range(1, MAX_ATTEMPTS + 1):
        try:
            budget.reserve(call_upper_cost)
        except EvaluationFailure as exc:
            final_error = exc.code
            break
        backoff = BACKOFF_SECONDS[attempt_number - 1]
        if backoff:
            sleep(backoff)
        attempt_started_at = utc_now()
        attempt_start_ns = clock_ns()
        result: HttpResult | None = None
        transport_failed = False
        try:
            result = send_request(request_body, REQUEST_TIMEOUT_SECONDS)
        except TransientTransportFailure:
            transport_failed = True
        attempt_end_ns = clock_ns()

        status_code = 0 if transport_failed else int(result.status_code)
        response = None if result is None else result.body
        usage = extract_usage(response)
        cost = usage_cost(usage, pricing)
        if isinstance(response, dict):
            if isinstance(response.get("model"), str):
                returned_model = response["model"]
            if isinstance(response.get("id"), str):
                response_id = response["id"]

        transient = transport_failed or status_code in TRANSIENT_HTTP_STATUSES
        attempt_error: str | None = None
        outcome: str
        if transient:
            outcome = "transient_error"
            attempt_error = "AI_PROVIDER_TRANSIENT"
            if attempt_number == MAX_ATTEMPTS:
                final_error = "AI_PROVIDER_TRANSIENT_EXHAUSTED"
                retry_exhausted = True
        elif not 200 <= status_code < 300:
            outcome = "permanent_error"
            attempt_error = "AI_PROVIDER_PERMANENT"
            final_error = attempt_error
        elif response is None:
            outcome = "invalid_response"
            attempt_error = "AI_RESPONSE_INVALID"
            final_error = attempt_error
        else:
            try:
                classification = validate_classification_response(response, contract)
                outcome = "success"
            except EvaluationFailure as exc:
                outcome = "invalid_response" if exc.code == "AI_RESPONSE_INVALID" else "permanent_error"
                attempt_error = exc.code
                final_error = exc.code

        attempts.append(
            {
                "run_id": run_id,
                "case_id": case["id"],
                "attempt_number": attempt_number,
                "backoff_before_seconds": backoff,
                "timestamp_started": attempt_started_at,
                "latency_ns": attempt_end_ns - attempt_start_ns,
                "latency_ms": (attempt_end_ns - attempt_start_ns) / 1_000_000,
                "http_status": status_code,
                "outcome": outcome,
                "error_code": attempt_error,
                "response_id": response_id,
                "returned_model": returned_model,
                "usage_accounting_status": usage["usage_accounting_status"],
                "input_tokens": usage["input_tokens"],
                "regular_input_tokens": usage["regular_input_tokens"],
                "cached_tokens": usage["cached_tokens"],
                "cache_write_tokens": usage["cache_write_tokens"],
                "output_tokens": usage["output_tokens"],
                "total_tokens": usage["total_tokens"],
                "usage_cost_usd": float(cost) if cost is not None else None,
            }
        )
        if classification is not None or not transient:
            break

    case_end_ns = clock_ns()
    usage_complete = bool(attempts) and all(
        attempt["usage_accounting_status"] == "complete" for attempt in attempts
    )
    usage_statuses = sorted({attempt["usage_accounting_status"] for attempt in attempts})
    aggregate_usage_status = (
        "complete"
        if usage_complete
        else "not_available"
        if not usage_statuses
        else usage_statuses[0]
        if len(usage_statuses) == 1
        else "mixed_incomplete"
    )
    def summed_attempt_field(field: str) -> int | None:
        values = [
            attempt[field]
            for attempt in attempts
            if isinstance(attempt.get(field), int) and not isinstance(attempt.get(field), bool)
        ]
        return sum(values) if values else None

    known_cost = sum(
        (Decimal(str(attempt["usage_cost_usd"])) for attempt in attempts if attempt["usage_cost_usd"] is not None),
        Decimal("0"),
    )

    predicted_category = classification["category"] if classification else None
    predicted_priority = classification["priority"] if classification else None
    category_correct = predicted_category == case["expected_category"] if classification else None
    priority_correct = predicted_priority == case["expected_priority"] if classification else None
    record = {
        "run_id": run_id,
        "case_id": case["id"],
        "expected_category": case["expected_category"],
        "predicted_category": predicted_category,
        "category_correct": category_correct,
        "expected_priority": case["expected_priority"],
        "predicted_priority": predicted_priority,
        "priority_correct": priority_correct,
        "exact_match": category_correct and priority_correct if classification else None,
        "predicted_summary": classification["summary"] if classification else None,
        "confidence_raw": classification["confidence"] if classification else None,
        "hitl_required": classification["review_required"] if classification else None,
        "hitl_reason": classification["review_reason"] if classification else None,
        "status": "succeeded" if classification else "error",
        "error_code": None if classification else (final_error or "AI_INTERNAL_ERROR"),
        "attempt_count": len(attempts),
        "first_attempt_success": classification is not None and len(attempts) == 1,
        "succeeded_after_retry": classification is not None and len(attempts) > 1,
        "retry_exhausted": retry_exhausted,
        "timestamp_started": case_started_at,
        "timestamp_finished": utc_now(),
        "latency_ns": case_end_ns - case_start_ns,
        "latency_ms": (case_end_ns - case_start_ns) / 1_000_000,
        "input_tokens": summed_attempt_field("input_tokens"),
        "regular_input_tokens": summed_attempt_field("regular_input_tokens") if usage_complete else None,
        "cached_tokens": summed_attempt_field("cached_tokens"),
        "cache_write_tokens": summed_attempt_field("cache_write_tokens") if usage_complete else None,
        "output_tokens": summed_attempt_field("output_tokens"),
        "total_tokens": summed_attempt_field("total_tokens"),
        "usage_accounting_status": aggregate_usage_status,
        "attempt_usage_accounting_statuses": usage_statuses,
        "token_usage_complete": usage_complete,
        "known_cost_usd": float(known_cost),
        "estimated_or_actual_cost_usd": float(known_cost) if usage_complete else None,
        "cost_complete": usage_complete,
        "response_id": response_id,
        "returned_model": returned_model,
    }
    return record, attempts


def execute_run(
    cases: list[dict[str, Any]],
    contract: Contract,
    pricing: Pricing,
    limits: Limits,
    manifest: dict[str, Any],
    run_dir: Path,
    send_request: Callable[[dict[str, Any], int], HttpResult],
    sleep: Callable[[float], None] = time.sleep,
) -> dict[str, Any]:
    from score_evaluation import score_files

    run_dir.mkdir(parents=True, exist_ok=False)
    predictions_path = run_dir / "predictions.jsonl"
    attempts_path = run_dir / "attempts.jsonl"
    predictions_path.touch()
    attempts_path.touch()
    manifest_path = run_dir / "manifest.json"
    write_json(manifest_path, manifest)

    budget = CallBudget(limits)
    records: list[dict[str, Any]] = []
    returned_models: set[str] = set()
    termination = "completed"
    for case in cases[: limits.max_cases]:
        try:
            record, attempts = evaluate_case(
                case, manifest["run_id"], contract, pricing, budget, send_request, sleep=sleep
            )
        except KeyboardInterrupt:
            termination = "interrupted"
            break
        except Exception:
            now = utc_now()
            record = {
                "run_id": manifest["run_id"],
                "case_id": case.get("id"),
                "expected_category": case.get("expected_category"),
                "predicted_category": None,
                "category_correct": None,
                "expected_priority": case.get("expected_priority"),
                "predicted_priority": None,
                "priority_correct": None,
                "exact_match": None,
                "predicted_summary": None,
                "confidence_raw": None,
                "hitl_required": None,
                "hitl_reason": None,
                "status": "error",
                "error_code": "AI_INTERNAL_ERROR",
                "attempt_count": 0,
                "first_attempt_success": False,
                "succeeded_after_retry": False,
                "retry_exhausted": False,
                "timestamp_started": now,
                "timestamp_finished": now,
                "latency_ns": None,
                "latency_ms": None,
                "input_tokens": None,
                "regular_input_tokens": None,
                "cached_tokens": None,
                "cache_write_tokens": None,
                "output_tokens": None,
                "total_tokens": None,
                "usage_accounting_status": "not_available",
                "attempt_usage_accounting_statuses": [],
                "token_usage_complete": False,
                "known_cost_usd": 0.0,
                "estimated_or_actual_cost_usd": None,
                "cost_complete": False,
                "response_id": None,
                "returned_model": None,
            }
            attempts = []
        for attempt in attempts:
            append_jsonl(attempts_path, attempt)
            if attempt.get("returned_model"):
                returned_models.add(attempt["returned_model"])
        append_jsonl(predictions_path, record)
        records.append(record)
        if record["error_code"] in {"EVAL_MAX_API_CALLS_REACHED", "EVAL_MAX_COST_REACHED"}:
            termination = "stopped_by_guard"
            break

    manifest["status"] = termination
    manifest["timestamp_finished"] = utc_now()
    manifest["returned_model_if_available"] = sorted(returned_models)
    manifest["execution"].update(
        {
            "attempted_case_count": len(records),
            "successful_classification_count": sum(record["status"] == "succeeded" for record in records),
            "errored_case_count": sum(record["status"] != "succeeded" for record in records),
            "api_calls_made": budget.api_calls,
            "conservative_budget_reserved_usd": float(budget.conservative_reserved_usd),
            "termination": termination,
        }
    )
    write_json(manifest_path, manifest)
    try:
        score_files(predictions_path, manifest_path, run_dir)
    except Exception:
        manifest["status"] = "scoring_failed"
        write_json(manifest_path, manifest)
        raise
    return manifest


def parse_decimal(value: str | None, name: str) -> Decimal:
    if value is None:
        raise ValueError(f"{name} is required")
    try:
        parsed = Decimal(value)
    except InvalidOperation as exc:
        raise ValueError(f"{name} must be a decimal") from exc
    if parsed < 0:
        raise ValueError(f"{name} cannot be negative")
    return parsed


def positive_int(value: str | None, name: str) -> int:
    if value is None:
        raise ValueError(f"{name} is required")
    parsed = int(value)
    if parsed < 1:
        raise ValueError(f"{name} must be positive")
    return parsed


def git_commit() -> str:
    return subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=REPO_ROOT, check=True, capture_output=True, text=True
    ).stdout.strip()


def relative_path(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO_ROOT).as_posix()
    except ValueError:
        return str(path.resolve())


def make_run_id() -> str:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"eval-{stamp}-{uuid.uuid4().hex[:8]}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", type=Path, required=True)
    parser.add_argument("--run-id")
    parser.add_argument("--runs-dir", type=Path, default=DEFAULT_RUNS_DIR)
    parser.add_argument("--max-cases", default=os.getenv("EVAL_MAX_CASES"))
    parser.add_argument("--max-api-calls", default=os.getenv("EVAL_MAX_API_CALLS"))
    parser.add_argument("--max-cost-usd", default=os.getenv("EVAL_MAX_USD"))
    parser.add_argument("--input-price-per-million-usd", default=os.getenv("EVAL_INPUT_PRICE_PER_1M_USD"))
    parser.add_argument("--cached-input-price-per-million-usd", default=os.getenv("EVAL_CACHED_INPUT_PRICE_PER_1M_USD"))
    parser.add_argument("--cache-write-price-per-million-usd", default=os.getenv("EVAL_CACHE_WRITE_PRICE_PER_1M_USD"))
    parser.add_argument("--output-price-per-million-usd", default=os.getenv("EVAL_OUTPUT_PRICE_PER_1M_USD"))
    parser.add_argument("--pricing-source", default=os.getenv("EVAL_PRICING_SOURCE"))
    parser.add_argument("--pricing-verification-date", default=os.getenv("EVAL_PRICING_VERIFICATION_DATE"))
    parser.add_argument("--api-key-env", default="OPENAI_API_KEY")
    parser.add_argument("--preflight-only", action="store_true")
    parser.add_argument("--allow-frozen-test", action="store_true")
    args = parser.parse_args()

    dataset_path = args.dataset.resolve()
    try:
        dataset_path.relative_to(REPO_ROOT / "eval" / "datasets")
    except ValueError:
        parser.error("dataset must be inside the versioned eval/datasets directory")
    if dataset_path.name == "test.jsonl" and not args.allow_frozen_test:
        parser.error("test.jsonl is sealed; --allow-frozen-test is required for a future official run")
    try:
        limits = Limits(
            max_cases=positive_int(args.max_cases, "max_cases"),
            max_api_calls=positive_int(args.max_api_calls, "max_api_calls"),
            max_cost_usd=parse_decimal(args.max_cost_usd, "max_cost_usd"),
        )
        if not args.pricing_source:
            raise ValueError("pricing_source is required")
        if not args.pricing_verification_date:
            raise ValueError("pricing_verification_date is required")
        verification_date = date.fromisoformat(args.pricing_verification_date)
        if verification_date.isoformat() != args.pricing_verification_date:
            raise ValueError("pricing_verification_date must use YYYY-MM-DD")
        pricing = Pricing(
            input_per_million_usd=parse_decimal(args.input_price_per_million_usd, "input price"),
            cached_input_per_million_usd=parse_decimal(args.cached_input_price_per_million_usd, "cached input price"),
            cache_write_per_million_usd=parse_decimal(args.cache_write_price_per_million_usd, "cache write price"),
            output_per_million_usd=parse_decimal(args.output_price_per_million_usd, "output price"),
            source=args.pricing_source,
            verification_date=args.pricing_verification_date,
        )
        if pricing.cached_input_per_million_usd > pricing.input_per_million_usd:
            raise ValueError("cached input price cannot exceed regular input price")
        dataset_manifest, cases = validate_versioned_dataset(dataset_path)
        contract = load_contract()
        selected_cases = cases[: limits.max_cases]
        preflight = build_preflight(cases, contract, pricing, limits)
    except (EvaluationFailure, OSError, ValueError, json.JSONDecodeError) as exc:
        parser.error(str(exc))

    if args.preflight_only:
        print(json.dumps(preflight, ensure_ascii=False, indent=2))
        return 0

    api_key = os.getenv(args.api_key_env)
    if not api_key:
        parser.error(f"API key environment variable {args.api_key_env!r} is not set")

    run_id = args.run_id or make_run_id()
    run_dir = args.runs_dir.resolve() / run_id
    if run_dir.exists():
        parser.error(f"Run directory already exists: {run_dir}")

    started = utc_now()
    manifest = {
        "run_id": run_id,
        "status": "running",
        "timestamp_started": started,
        "timestamp_finished": None,
        "git_commit": git_commit(),
        "dataset": {
            "path": relative_path(dataset_path),
            "version": dataset_manifest["dataset_version"],
            "sha256": sha256_file(dataset_path),
            "split": selected_cases[0]["split"],
            "file_record_count": len(cases),
        },
        "contract": {
            "prompt_path": relative_path(PROMPT_PATH),
            "prompt_version": PROMPT_VERSION,
            "prompt_sha256": contract.prompt_sha256,
            "schema_path": relative_path(PRODUCTION_SCHEMA_PATH),
            "schema_version": SCHEMA_VERSION,
            "schema_sha256": contract.schema_sha256,
            "categories": contract.categories,
            "priorities": contract.priorities,
        },
        "provider": PROVIDER,
        "endpoint": ENDPOINT,
        "requested_model": REQUESTED_MODEL,
        "returned_model_if_available": [],
        "request_configuration": {
            "store": False,
            "reasoning": {"effort": "none"},
            "structured_output": {"type": "json_schema", "strict": True},
            "max_output_tokens": MAX_OUTPUT_TOKENS,
            "timeout_seconds": REQUEST_TIMEOUT_SECONDS,
        },
        "retry_policy": {
            "max_attempts": MAX_ATTEMPTS,
            "backoff_seconds_before_attempts": list(BACKOFF_SECONDS),
            "transient_http_statuses": sorted(TRANSIENT_HTTP_STATUSES),
            "network_timeout_status_zero_transient": True,
        },
        "hitl_policy": {
            "rule": "confidence < 0.75",
            "threshold": HITL_THRESHOLD,
            "confidence_semantics": "operational uncalibrated score; not a probability",
        },
        "pricing": {
            "source_or_version": pricing.source,
            "verification_date": pricing.verification_date,
            "currency": "USD",
            "unit": "per 1,000,000 tokens",
            "input_usd": float(pricing.input_per_million_usd),
            "cached_read_usd": float(pricing.cached_input_per_million_usd),
            "cache_write_usd": float(pricing.cache_write_per_million_usd),
            "output_usd": float(pricing.output_per_million_usd),
            "formula": "(regular_input*input_price + cached_read*cached_read_price + cache_write*cache_write_price + output*output_price) / 1,000,000; regular_input=input-cached_read-cache_write",
        },
        "guardrails": {
            "max_cases": limits.max_cases,
            "max_api_calls": limits.max_api_calls,
            "max_cost_usd": float(limits.max_cost_usd),
            "frozen_test_requires_explicit_flag": True,
        },
        "preflight": preflight,
        "execution": {
            "selected_case_count": len(selected_cases),
            "attempted_case_count": 0,
            "successful_classification_count": 0,
            "errored_case_count": 0,
            "api_calls_made": 0,
            "termination": None,
        },
        "runtime": {
            "python": platform.python_version(),
            "implementation": platform.python_implementation(),
            "platform": platform.platform(),
            "external_dependencies": [],
        },
    }
    client = OpenAIClient(api_key)
    final_manifest = execute_run(
        selected_cases, contract, pricing, limits, manifest, run_dir, client.send
    )
    print(json.dumps({"run_dir": str(run_dir), "status": final_manifest["status"]}, indent=2))
    return 0 if final_manifest["status"] == "completed" else 2


if __name__ == "__main__":
    raise SystemExit(main())
