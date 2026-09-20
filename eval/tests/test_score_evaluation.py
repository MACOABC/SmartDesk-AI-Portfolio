from __future__ import annotations

import json
import os
import socket
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = REPO_ROOT / "eval" / "scripts"
sys.path.insert(0, str(SCRIPTS))

import score_evaluation as scorer  # noqa: E402


CATEGORIES = ["access", "hardware", "software", "network", "service_request", "other"]
PRIORITIES = ["low", "medium", "high", "critical"]


def prediction(
    case_id: str,
    expected_category: str,
    predicted_category: str | None,
    expected_priority: str,
    predicted_priority: str | None,
    hitl: bool | None,
    attempts: int,
    latency: float,
    status: str = "succeeded",
    retry_exhausted: bool = False,
) -> dict[str, object]:
    valid = status == "succeeded"
    exact = valid and expected_category == predicted_category and expected_priority == predicted_priority
    return {
        "run_id": "score-test",
        "case_id": case_id,
        "expected_category": expected_category,
        "predicted_category": predicted_category,
        "category_correct": expected_category == predicted_category if valid else None,
        "expected_priority": expected_priority,
        "predicted_priority": predicted_priority,
        "priority_correct": expected_priority == predicted_priority if valid else None,
        "exact_match": exact if valid else None,
        "hitl_required": hitl,
        "status": status,
        "error_code": None if valid else "AI_PROVIDER_TRANSIENT_EXHAUSTED",
        "attempt_count": attempts,
        "retry_exhausted": retry_exhausted,
        "latency_ms": latency,
        "input_tokens": 100,
        "cached_input_tokens": 0,
        "output_tokens": 20,
        "total_tokens": 120,
        "estimated_or_actual_cost_usd": 0.001,
    }


class ScoringTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = {
            "run_id": "score-test",
            "contract": {"categories": CATEGORIES, "priorities": PRIORITIES},
            "execution": {"selected_case_count": 5},
            "pricing": {"source_or_version": "unit-test"},
            "preflight": {"estimated_max_cost_usd": 1.0},
        }
        self.records = [
            prediction("1", "access", "access", "low", "low", False, 1, 10.0),
            prediction("2", "access", "network", "high", "high", False, 1, 20.0),
            prediction("3", "hardware", "hardware", "critical", "high", True, 2, 30.0),
            prediction("4", "software", None, "medium", None, None, 3, 40.0, "error", True),
        ]

    def test_metrics_confusion_denominators_exact_match_and_hitl(self) -> None:
        metrics = scorer.compute_metrics(self.records, self.manifest)
        self.assertEqual(metrics["denominators"]["dataset_cases"], 5)
        self.assertEqual(metrics["denominators"]["attempted_cases"], 4)
        self.assertEqual(metrics["denominators"]["valid_classifications"], 3)
        self.assertEqual(metrics["denominators"]["errored_cases"], 1)
        self.assertAlmostEqual(metrics["category"]["accuracy"], 2 / 3)
        self.assertAlmostEqual(metrics["priority"]["accuracy"], 2 / 3)
        self.assertAlmostEqual(metrics["exact_match"]["rate"], 1 / 3)
        self.assertEqual(metrics["category"]["confusion_matrix"]["values"][0][0], 1)
        self.assertEqual(metrics["category"]["confusion_matrix"]["values"][0][3], 1)
        self.assertAlmostEqual(metrics["hitl"]["review_rate"], 1 / 3)
        self.assertAlmostEqual(metrics["hitl"]["auto_coverage"], 2 / 3)
        self.assertEqual(metrics["hitl"]["accuracy_auto_resolved"], 0.5)
        self.assertEqual(metrics["hitl"]["accuracy_hitl_subset"], 0.0)
        self.assertEqual(metrics["hitl"]["error_escape_count"], 1)
        self.assertEqual(metrics["hitl"]["error_escape_rate"], 0.5)

    def test_reliability_latency_tokens_and_cost(self) -> None:
        metrics = scorer.compute_metrics(self.records, self.manifest)
        reliability = metrics["reliability"]
        self.assertEqual(reliability["api_attempts"], 7)
        self.assertEqual(reliability["retry_count"], 3)
        self.assertEqual(reliability["first_attempt_successes"], 2)
        self.assertEqual(reliability["eventually_successful_after_retry"], 1)
        self.assertEqual(reliability["retry_exhausted"], 1)
        self.assertEqual(reliability["unattempted_dataset_cases"], 1)
        self.assertEqual(metrics["latency_ms"]["mean"], 25.0)
        self.assertEqual(metrics["latency_ms"]["p50"], 25.0)
        self.assertAlmostEqual(metrics["latency_ms"]["p95"], 38.5)
        self.assertEqual(metrics["tokens_and_cost"]["total_tokens"], 480)
        self.assertTrue(metrics["tokens_and_cost"]["cost_complete"])
        self.assertEqual(metrics["tokens_and_cost"]["total_cost_usd"], 0.004)

    def test_offline_scoring_writes_artifacts_without_key_or_network(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            predictions = directory / "predictions.jsonl"
            manifest = directory / "manifest.json"
            predictions.write_text(
                "\n".join(json.dumps(record) for record in self.records) + "\n", encoding="utf-8"
            )
            manifest.write_text(json.dumps(self.manifest), encoding="utf-8")
            environment = dict(os.environ)
            environment.pop("OPENAI_API_KEY", None)
            with mock.patch.dict(os.environ, environment, clear=True), mock.patch.object(
                socket, "create_connection", side_effect=AssertionError("network must not be used")
            ):
                metrics, cost = scorer.score_files(predictions, manifest, directory)
            self.assertEqual(metrics["run_id"], "score-test")
            self.assertEqual(cost["run_id"], "score-test")
            self.assertTrue((directory / "metrics.json").exists())
            self.assertTrue((directory / "cost.json").exists())

    def test_missing_cost_is_not_invented(self) -> None:
        records = [dict(self.records[0]), dict(self.records[1])]
        records[1]["estimated_or_actual_cost_usd"] = None
        metrics = scorer.compute_metrics(records, {**self.manifest, "execution": {"selected_case_count": 2}})
        self.assertFalse(metrics["tokens_and_cost"]["cost_complete"])
        self.assertIsNone(metrics["tokens_and_cost"]["total_cost_usd"])
        self.assertEqual(metrics["tokens_and_cost"]["known_cost_usd"], 0.001)


if __name__ == "__main__":
    unittest.main()
