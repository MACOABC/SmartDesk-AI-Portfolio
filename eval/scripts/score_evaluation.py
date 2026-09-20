#!/usr/bin/env python3
"""Score SmartDesk evaluation predictions completely offline."""

from __future__ import annotations

import argparse
import json
import math
import statistics
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            raise ValueError(f"{path}:{line_number}: blank line")
        value = json.loads(line)
        if not isinstance(value, dict):
            raise ValueError(f"{path}:{line_number}: record must be an object")
        records.append(value)
    return records


def write_json(path: Path, value: dict[str, Any]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def safe_ratio(numerator: int | float, denominator: int | float) -> float | None:
    return numerator / denominator if denominator else None


def percentile(values: list[float], quantile: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = (len(ordered) - 1) * quantile
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def pricing_values(manifest: dict[str, Any]) -> dict[str, Decimal]:
    pricing = manifest.get("pricing")
    if not isinstance(pricing, dict):
        raise ValueError("Run manifest must include pricing")
    result: dict[str, Decimal] = {}
    for key in ("input_usd", "cached_read_usd", "cache_write_usd", "output_usd"):
        value = pricing.get(key)
        if isinstance(value, bool) or not isinstance(value, (int, float, str)):
            raise ValueError(f"Run manifest pricing.{key} must be a non-negative decimal")
        try:
            parsed = Decimal(str(value))
        except InvalidOperation as exc:
            raise ValueError(f"Run manifest pricing.{key} must be a non-negative decimal") from exc
        if not parsed.is_finite() or parsed < 0:
            raise ValueError(f"Run manifest pricing.{key} must be a non-negative decimal")
        result[key] = parsed
    return result


def recompute_record_cost(
    record: dict[str, Any], prices: dict[str, Decimal]
) -> tuple[Decimal | None, str]:
    fields = (
        "input_tokens",
        "regular_input_tokens",
        "cached_tokens",
        "cache_write_tokens",
        "output_tokens",
        "total_tokens",
    )
    values: dict[str, int] = {}
    for field in fields:
        value = record.get(field)
        if value is None:
            return None, "incomplete"
        if isinstance(value, bool) or not isinstance(value, int) or value < 0:
            return None, "invalid"
        values[field] = value
    if values["total_tokens"] != values["input_tokens"] + values["output_tokens"]:
        return None, "invalid"
    if (
        values["regular_input_tokens"]
        + values["cached_tokens"]
        + values["cache_write_tokens"]
        != values["input_tokens"]
    ):
        return None, "invalid"
    cost = (
        Decimal(values["regular_input_tokens"]) * prices["input_usd"]
        + Decimal(values["cached_tokens"]) * prices["cached_read_usd"]
        + Decimal(values["cache_write_tokens"]) * prices["cache_write_usd"]
        + Decimal(values["output_tokens"]) * prices["output_usd"]
    ) / Decimal(1_000_000)
    return cost, "complete"


def classification_metrics(
    records: list[dict[str, Any]],
    labels: list[str],
    expected_field: str,
    predicted_field: str,
) -> dict[str, Any]:
    matrix = {expected: {predicted: 0 for predicted in labels} for expected in labels}
    correct = 0
    for record in records:
        expected = record[expected_field]
        predicted = record[predicted_field]
        if expected not in matrix or predicted not in matrix[expected]:
            raise ValueError(f"Unknown label while scoring {expected_field}: {expected!r}/{predicted!r}")
        matrix[expected][predicted] += 1
        correct += int(expected == predicted)

    per_class: dict[str, dict[str, Any]] = {}
    f1_values: list[float] = []
    for label in labels:
        true_positive = matrix[label][label]
        false_positive = sum(matrix[other][label] for other in labels if other != label)
        false_negative = sum(matrix[label][other] for other in labels if other != label)
        support = sum(matrix[label].values())
        predicted_count = sum(matrix[other][label] for other in labels)
        precision = safe_ratio(true_positive, true_positive + false_positive)
        recall = safe_ratio(true_positive, true_positive + false_negative)
        if precision is None or recall is None or precision + recall == 0:
            f1 = 0.0
        else:
            f1 = 2 * precision * recall / (precision + recall)
        f1_values.append(f1)
        per_class[label] = {
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "support": support,
            "predicted": predicted_count,
            "true_positive": true_positive,
        }

    return {
        "denominator_valid_classifications": len(records),
        "correct": correct,
        "accuracy": safe_ratio(correct, len(records)),
        "macro_f1": statistics.fmean(f1_values) if f1_values else None,
        "per_class": per_class,
        "confusion_matrix": {
            "row_labels_expected": labels,
            "column_labels_predicted": labels,
            "values": [[matrix[expected][predicted] for predicted in labels] for expected in labels],
        },
    }


def compute_metrics(records: list[dict[str, Any]], manifest: dict[str, Any]) -> dict[str, Any]:
    contract = manifest.get("contract", {})
    categories = list(contract.get("categories", []))
    priorities = list(contract.get("priorities", []))
    if not categories or not priorities:
        raise ValueError("Run manifest must include contract.categories and contract.priorities")

    run_id = manifest.get("run_id")
    case_ids = [record.get("case_id") for record in records]
    if len(set(case_ids)) != len(case_ids) or any(
        not isinstance(case_id, str) or not case_id for case_id in case_ids
    ):
        raise ValueError("Prediction case_id values must be unique non-empty strings")
    if any(record.get("run_id") != run_id for record in records):
        raise ValueError("Every prediction run_id must match the run manifest")

    valid = [record for record in records if record.get("status") == "succeeded"]
    errors = [record for record in records if record.get("status") != "succeeded"]
    for record in valid:
        if record.get("predicted_category") not in categories or record.get("predicted_priority") not in priorities:
            raise ValueError(f"Successful record {record.get('case_id')} has an invalid predicted label")
        if not isinstance(record.get("hitl_required"), bool):
            raise ValueError(f"Successful record {record.get('case_id')} must contain boolean hitl_required")

    dataset_cases = int(manifest.get("execution", {}).get("selected_case_count", len(records)))
    attempted_cases = len(records)
    if attempted_cases > dataset_cases:
        raise ValueError("Predictions contain more attempted cases than the run manifest selected")
    is_exact = lambda record: (
        record.get("predicted_category") == record.get("expected_category")
        and record.get("predicted_priority") == record.get("expected_priority")
    )
    exact_correct = sum(
        1
        for record in valid
        if is_exact(record)
    )

    reviewed = [record for record in valid if record.get("hitl_required") is True]
    auto_resolved = [record for record in valid if record.get("hitl_required") is False]
    auto_correct = sum(1 for record in auto_resolved if is_exact(record))
    reviewed_correct = sum(1 for record in reviewed if is_exact(record))
    escaped = [record for record in auto_resolved if not is_exact(record)]

    latencies = [float(record["latency_ms"]) for record in records if isinstance(record.get("latency_ms"), (int, float))]
    api_attempts = sum(int(record.get("attempt_count", 0)) for record in records)
    first_attempt_successes = sum(1 for record in valid if record.get("attempt_count") == 1)
    eventually_after_retry = sum(1 for record in valid if int(record.get("attempt_count", 0)) > 1)
    retry_exhausted = sum(1 for record in records if record.get("retry_exhausted") is True)

    token_fields = (
        "input_tokens",
        "regular_input_tokens",
        "cached_tokens",
        "cache_write_tokens",
        "output_tokens",
        "total_tokens",
    )
    token_summary: dict[str, Any] = {}
    for field in token_fields:
        known = [int(record[field]) for record in records if isinstance(record.get(field), int)]
        token_summary[field] = sum(known)
        token_summary[f"{field}_missing_records"] = attempted_cases - len(known)

    prices = pricing_values(manifest)
    recomputed = [recompute_record_cost(record, prices) for record in records]
    known_costs = [cost for cost, status in recomputed if status == "complete" and cost is not None]
    cost_complete = len(known_costs) == attempted_cases
    valid_ids = {id(record) for record in valid}
    known_valid_costs = [
        cost
        for record, (cost, status) in zip(records, recomputed)
        if id(record) in valid_ids and status == "complete" and cost is not None
    ]
    valid_cost_complete = len(known_valid_costs) == len(valid)
    known_cost = sum(known_costs, Decimal("0"))
    accounting_status_counts = {
        status: sum(1 for _, observed_status in recomputed if observed_status == status)
        for status in ("complete", "incomplete", "invalid")
    }

    return {
        "generated_at": utc_now(),
        "run_id": manifest.get("run_id"),
        "denominators": {
            "dataset_cases": dataset_cases,
            "attempted_cases": attempted_cases,
            "valid_classifications": len(valid),
            "errored_cases": len(errors),
            "classification_accuracy": "correct predictions / valid classifications",
            "operational_error_rate": "errored cases / attempted cases",
            "hitl_rates": "valid classifications",
            "error_escape_rate": "incorrect auto-resolved predictions / auto-resolved predictions",
        },
        "category": classification_metrics(valid, categories, "expected_category", "predicted_category"),
        "priority": classification_metrics(valid, priorities, "expected_priority", "predicted_priority"),
        "exact_match": {
            "correct": exact_correct,
            "denominator_valid_classifications": len(valid),
            "rate": safe_ratio(exact_correct, len(valid)),
        },
        "hitl": {
            "reviewed_cases": len(reviewed),
            "auto_resolved_cases": len(auto_resolved),
            "review_rate": safe_ratio(len(reviewed), len(valid)),
            "auto_coverage": safe_ratio(len(auto_resolved), len(valid)),
            "accuracy_auto_resolved": safe_ratio(auto_correct, len(auto_resolved)),
            "accuracy_hitl_subset": safe_ratio(reviewed_correct, len(reviewed)),
            "error_escape_count": len(escaped),
            "error_escape_rate": safe_ratio(len(escaped), len(auto_resolved)),
        },
        "reliability": {
            "dataset_cases": dataset_cases,
            "attempted_cases": attempted_cases,
            "successful_classifications": len(valid),
            "errored_cases": len(errors),
            "error_rate": safe_ratio(len(errors), attempted_cases),
            "api_attempts": api_attempts,
            "retry_count": sum(max(int(record.get("attempt_count", 0)) - 1, 0) for record in records),
            "first_attempt_successes": first_attempt_successes,
            "eventually_successful_after_retry": eventually_after_retry,
            "retry_exhausted": retry_exhausted,
            "unattempted_dataset_cases": max(dataset_cases - attempted_cases, 0),
        },
        "latency_ms": {
            "definition": "end-to-end case time in the harness, including API attempts, validation and retry backoff",
            "sample_count": len(latencies),
            "mean": statistics.fmean(latencies) if latencies else None,
            "p50": percentile(latencies, 0.50),
            "p95": percentile(latencies, 0.95),
            "min": min(latencies) if latencies else None,
            "max": max(latencies) if latencies else None,
        },
        "tokens_and_cost": {
            **token_summary,
            "cost_source": "offline recomputation from raw token counters and manifest pricing",
            "usage_accounting_status_counts": accounting_status_counts,
            "known_cost_usd": float(known_cost),
            "cost_complete": cost_complete,
            "records_missing_cost": attempted_cases - len(known_costs),
            "total_cost_usd": float(known_cost) if cost_complete else None,
            "average_cost_per_attempted_ticket_usd": float(known_cost / attempted_cases) if cost_complete and attempted_cases else None,
            "average_cost_per_valid_classification_usd": float(sum(known_valid_costs, Decimal("0")) / len(valid)) if valid_cost_complete and valid else None,
        },
    }


def score_files(predictions_path: Path, manifest_path: Path, output_dir: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    manifest = read_json(manifest_path)
    records = read_jsonl(predictions_path)
    metrics = compute_metrics(records, manifest)
    cost = {
        "generated_at": metrics["generated_at"],
        "run_id": manifest.get("run_id"),
        "pricing": manifest.get("pricing"),
        "preflight": manifest.get("preflight"),
        "observed": metrics["tokens_and_cost"],
        "note": "Observed cost is recomputed offline and is complete only when every attempted case has internally consistent regular, cached-read, cache-write, output and total token counters.",
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    write_json(output_dir / "metrics.json", metrics)
    write_json(output_dir / "cost.json", cost)
    return metrics, cost


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--predictions", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    output_dir = (args.output_dir or args.predictions.parent).resolve()
    metrics, _ = score_files(args.predictions.resolve(), args.manifest.resolve(), output_dir)
    print(json.dumps(metrics, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
