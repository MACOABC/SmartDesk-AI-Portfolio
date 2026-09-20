from __future__ import annotations

import json
import sys
import tempfile
import unittest
from decimal import Decimal
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = REPO_ROOT / "eval" / "scripts"
sys.path.insert(0, str(SCRIPTS))

import run_evaluation as runner  # noqa: E402


def sample_case(identifier: str = "SD-EVAL-DEV-001") -> dict[str, object]:
    return {
        "id": identifier,
        "split": "dev",
        "area": "Área visible",
        "title": "Título visible",
        "description": "Descripción visible y suficientemente larga.",
        "expected_category": "GROUND_TRUTH_CATEGORY_SENTINEL",
        "expected_priority": "GROUND_TRUTH_PRIORITY_SENTINEL",
        "difficulty": "GROUND_TRUTH_DIFFICULTY_SENTINEL",
        "scenario_type": "GROUND_TRUTH_SCENARIO_SENTINEL",
        "ground_truth_notes": "GROUND_TRUTH_NOTES_SENTINEL",
    }


def api_response(
    category: str = "access",
    priority: str = "medium",
    confidence: float = 0.9,
    review_reason: str | None = None,
    text_override: str | None = None,
    usage: tuple[int, int, int, int, int] = (100, 10, 5, 20, 120),
) -> dict[str, object]:
    classification = {
        "category": category,
        "priority": priority,
        "summary": "Resumen operativo",
        "confidence": confidence,
        "review_required": confidence < runner.HITL_THRESHOLD,
        "review_reason": review_reason if confidence < runner.HITL_THRESHOLD else None,
    }
    text = text_override if text_override is not None else json.dumps(classification)
    input_tokens, cached_tokens, cache_write_tokens, output_tokens, total_tokens = usage
    return {
        "id": "resp_test",
        "model": "gpt-5.6-luna-2026-09-01",
        "status": "completed",
        "error": None,
        "output": [{"type": "message", "content": [{"type": "output_text", "text": text}]}],
        "usage": {
            "input_tokens": input_tokens,
            "input_tokens_details": {
                "cached_tokens": cached_tokens,
                "cache_write_tokens": cache_write_tokens,
            },
            "output_tokens": output_tokens,
            "total_tokens": total_tokens,
        },
    }


class FakeSender:
    def __init__(self, *results: object):
        self.results = list(results)
        self.calls: list[dict[str, object]] = []

    def __call__(self, body: dict[str, object], timeout: int) -> runner.HttpResult:
        self.calls.append({"body": body, "timeout": timeout})
        result = self.results.pop(0)
        if isinstance(result, Exception):
            raise result
        return result  # type: ignore[return-value]


class SequenceClock:
    def __init__(self, *values: int):
        self.values = iter(values)

    def __call__(self) -> int:
        return next(self.values)


class RunnerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = runner.load_contract()
        cls.pricing = runner.Pricing(
            Decimal("1"), Decimal("0.5"), Decimal("1.25"), Decimal("2"), "unit-test", "2026-09-20"
        )

    def budget(self, calls: int = 10, usd: str = "10") -> runner.CallBudget:
        return runner.CallBudget(runner.Limits(max_cases=10, max_api_calls=calls, max_cost_usd=Decimal(usd)))

    def test_request_reuses_product_contract_and_excludes_ground_truth(self) -> None:
        body = runner.build_request_body(sample_case(), self.contract)
        serialized = json.dumps(body, ensure_ascii=False)
        self.assertEqual(body["model"], runner.REQUESTED_MODEL)
        self.assertEqual(body["max_output_tokens"], 450)
        self.assertEqual(body["reasoning"], {"effort": "none"})
        self.assertFalse(body["store"])
        self.assertTrue(body["text"]["format"]["strict"])
        self.assertEqual(body["instructions"], self.contract.prompt)
        for sentinel in (
            "GROUND_TRUTH_CATEGORY_SENTINEL",
            "GROUND_TRUTH_PRIORITY_SENTINEL",
            "GROUND_TRUTH_DIFFICULTY_SENTINEL",
            "GROUND_TRUTH_SCENARIO_SENTINEL",
            "GROUND_TRUTH_NOTES_SENTINEL",
        ):
            self.assertNotIn(sentinel, serialized)
        self.assertIn("Área visible", serialized)
        self.assertIn("Título visible", serialized)
        self.assertIn("Descripción visible", serialized)

    def test_happy_path_latency_tokens_and_cost(self) -> None:
        case = sample_case()
        case["expected_category"] = "access"
        case["expected_priority"] = "medium"
        sender = FakeSender(runner.HttpResult(200, api_response()))
        record, attempts = runner.evaluate_case(
            case,
            "run-test",
            self.contract,
            self.pricing,
            self.budget(),
            sender,
            clock_ns=SequenceClock(0, 1_000_000, 11_000_000, 21_000_000),
        )
        self.assertEqual(record["status"], "succeeded")
        self.assertTrue(record["exact_match"])
        self.assertEqual(record["latency_ns"], 21_000_000)
        self.assertEqual(record["latency_ms"], 21.0)
        self.assertEqual(attempts[0]["latency_ms"], 10.0)
        self.assertEqual(record["input_tokens"], 100)
        self.assertEqual(record["regular_input_tokens"], 85)
        self.assertEqual(record["cached_tokens"], 10)
        self.assertEqual(record["cache_write_tokens"], 5)
        self.assertEqual(record["total_tokens"], 120)
        self.assertTrue(record["cost_complete"])
        self.assertAlmostEqual(record["estimated_or_actual_cost_usd"], 0.00013625)
        self.assertEqual(sender.calls[0]["timeout"], 60)

    def test_usage_cost_with_only_uncached_input(self) -> None:
        usage = runner.extract_usage(api_response(usage=(100, 0, 0, 0, 100)))
        self.assertEqual(usage["regular_input_tokens"], 100)
        self.assertEqual(runner.usage_cost(usage, self.pricing), Decimal("0.0001"))

    def test_usage_cost_with_cached_read(self) -> None:
        usage = runner.extract_usage(api_response(usage=(100, 40, 0, 0, 100)))
        self.assertEqual(usage["regular_input_tokens"], 60)
        self.assertEqual(runner.usage_cost(usage, self.pricing), Decimal("0.00008"))

    def test_usage_cost_with_cache_write(self) -> None:
        usage = runner.extract_usage(api_response(usage=(100, 0, 30, 0, 100)))
        self.assertEqual(usage["regular_input_tokens"], 70)
        self.assertEqual(runner.usage_cost(usage, self.pricing), Decimal("0.0001075"))

    def test_usage_cost_with_all_input_classes_and_output(self) -> None:
        usage = runner.extract_usage(api_response(usage=(100, 20, 30, 20, 120)))
        self.assertEqual(usage["regular_input_tokens"], 50)
        self.assertEqual(runner.usage_cost(usage, self.pricing), Decimal("0.0001375"))

    def test_inconsistent_usage_is_invalid_and_has_no_cost(self) -> None:
        usage = runner.extract_usage(api_response(usage=(100, 80, 30, 20, 120)))
        self.assertEqual(usage["usage_accounting_status"], "invalid")
        self.assertIsNone(usage["regular_input_tokens"])
        self.assertIsNone(runner.usage_cost(usage, self.pricing))

    def test_absent_cache_write_is_recorded_as_not_reported(self) -> None:
        response = api_response()
        del response["usage"]["input_tokens_details"]["cache_write_tokens"]  # type: ignore[index]
        usage = runner.extract_usage(response)
        self.assertEqual(usage["usage_accounting_status"], "cache_write_tokens_not_reported")
        self.assertIsNone(usage["cache_write_tokens"])
        self.assertIsNone(runner.usage_cost(usage, self.pricing))
        record, attempts = runner.evaluate_case(
            sample_case(),
            "run",
            self.contract,
            self.pricing,
            self.budget(),
            FakeSender(runner.HttpResult(200, response)),
        )
        self.assertEqual(record["usage_accounting_status"], "cache_write_tokens_not_reported")
        self.assertIsNone(record["cache_write_tokens"])
        self.assertIsNone(record["estimated_or_actual_cost_usd"])
        self.assertEqual(attempts[0]["usage_accounting_status"], "cache_write_tokens_not_reported")

    def test_hitl_rule_is_reproduced_exactly(self) -> None:
        case = sample_case()
        case["expected_category"] = "other"
        case["expected_priority"] = "medium"
        sender = FakeSender(
            runner.HttpResult(200, api_response("other", "medium", 0.7, "Caso ambiguo"))
        )
        record, _ = runner.evaluate_case(case, "run", self.contract, self.pricing, self.budget(), sender)
        self.assertTrue(record["hitl_required"])
        self.assertEqual(record["hitl_reason"], "Caso ambiguo")
        self.assertEqual(record["confidence_raw"], 0.7)

    def test_invalid_json_is_not_retried(self) -> None:
        sender = FakeSender(runner.HttpResult(200, api_response(text_override="not-json")))
        record, _ = runner.evaluate_case(sample_case(), "run", self.contract, self.pricing, self.budget(), sender)
        self.assertEqual(record["error_code"], "AI_RESPONSE_INVALID")
        self.assertEqual(record["attempt_count"], 1)
        self.assertEqual(len(sender.calls), 1)

    def test_invalid_enum_is_not_retried(self) -> None:
        sender = FakeSender(runner.HttpResult(200, api_response(category="security")))
        record, _ = runner.evaluate_case(sample_case(), "run", self.contract, self.pricing, self.budget(), sender)
        self.assertEqual(record["error_code"], "AI_RESPONSE_INVALID")
        self.assertEqual(record["attempt_count"], 1)

    def test_non_retryable_http_error_stops_after_one_attempt(self) -> None:
        sender = FakeSender(runner.HttpResult(400, None))
        record, attempts = runner.evaluate_case(sample_case(), "run", self.contract, self.pricing, self.budget(), sender)
        self.assertEqual(record["error_code"], "AI_PROVIDER_PERMANENT")
        self.assertEqual(len(attempts), 1)

    def test_non_null_provider_error_is_permanent_even_when_empty(self) -> None:
        response = api_response()
        response["error"] = {}
        sender = FakeSender(runner.HttpResult(200, response))
        record, attempts = runner.evaluate_case(
            sample_case(), "run", self.contract, self.pricing, self.budget(), sender
        )
        self.assertEqual(record["error_code"], "AI_PROVIDER_PERMANENT")
        self.assertEqual(len(attempts), 1)

    def test_transient_error_retries_then_succeeds(self) -> None:
        sender = FakeSender(runner.HttpResult(503, None), runner.HttpResult(200, api_response()))
        sleeps: list[float] = []
        record, attempts = runner.evaluate_case(
            sample_case(), "run", self.contract, self.pricing, self.budget(), sender, sleep=sleeps.append
        )
        self.assertEqual(record["status"], "succeeded")
        self.assertTrue(record["succeeded_after_retry"])
        self.assertEqual(record["attempt_count"], 2)
        self.assertEqual(sleeps, [2])
        self.assertEqual([attempt["outcome"] for attempt in attempts], ["transient_error", "success"])

    def test_network_error_is_transient(self) -> None:
        sender = FakeSender(runner.TransientTransportFailure(), runner.HttpResult(200, api_response()))
        record, _ = runner.evaluate_case(
            sample_case(), "run", self.contract, self.pricing, self.budget(), sender, sleep=lambda _: None
        )
        self.assertEqual(record["status"], "succeeded")
        self.assertEqual(record["attempt_count"], 2)

    def test_retry_exhaustion_is_controlled(self) -> None:
        sender = FakeSender(*(runner.HttpResult(503, None) for _ in range(3)))
        sleeps: list[float] = []
        record, attempts = runner.evaluate_case(
            sample_case(), "run", self.contract, self.pricing, self.budget(), sender, sleep=sleeps.append
        )
        self.assertEqual(record["error_code"], "AI_PROVIDER_TRANSIENT_EXHAUSTED")
        self.assertTrue(record["retry_exhausted"])
        self.assertEqual(len(attempts), 3)
        self.assertEqual(sleeps, [2, 4])

    def test_api_call_guard_stops_before_second_call(self) -> None:
        sender = FakeSender(runner.HttpResult(503, None))
        record, attempts = runner.evaluate_case(
            sample_case(), "run", self.contract, self.pricing, self.budget(calls=1), sender, sleep=lambda _: None
        )
        self.assertEqual(record["error_code"], "EVAL_MAX_API_CALLS_REACHED")
        self.assertEqual(len(attempts), 1)
        self.assertEqual(len(sender.calls), 1)

    def test_cost_guard_stops_before_call(self) -> None:
        sender = FakeSender(runner.HttpResult(200, api_response()))
        record, attempts = runner.evaluate_case(
            sample_case(), "run", self.contract, self.pricing, self.budget(usd="0.000001"), sender
        )
        self.assertEqual(record["error_code"], "EVAL_MAX_COST_REACHED")
        self.assertEqual(attempts, [])
        self.assertEqual(sender.calls, [])

    def test_preflight_enforces_max_cases_and_budget(self) -> None:
        cases = [sample_case(f"SD-EVAL-DEV-{number:03d}") for number in range(1, 4)]
        preflight = runner.build_preflight(
            cases,
            self.contract,
            self.pricing,
            runner.Limits(max_cases=2, max_api_calls=6, max_cost_usd=Decimal("10")),
        )
        self.assertEqual(preflight["selected_cases"], 2)
        with self.assertRaisesRegex(ValueError, "exceeds max_cost_usd"):
            runner.build_preflight(
                cases,
                self.contract,
                self.pricing,
                runner.Limits(max_cases=2, max_api_calls=6, max_cost_usd=Decimal("0.000001")),
            )

    def test_every_split_checks_the_independent_frozen_test_hash(self) -> None:
        dev_path = REPO_ROOT / "eval" / "datasets" / "v1" / "dev.jsonl"
        real_sha256 = runner.sha256_file

        def altered_test_hash(path: Path) -> str:
            return "0" * 64 if path.name == "test.jsonl" else real_sha256(path)

        with mock.patch.object(runner, "sha256_file", side_effect=altered_test_hash):
            with self.assertRaisesRegex(ValueError, "Frozen test SHA-256"):
                runner.validate_versioned_dataset(dev_path)

    def test_partial_run_preserves_artifacts_and_does_not_overwrite(self) -> None:
        first = sample_case("SD-EVAL-DEV-001")
        first["expected_category"] = "access"
        first["expected_priority"] = "medium"
        second = sample_case("SD-EVAL-DEV-002")
        second["expected_category"] = "hardware"
        second["expected_priority"] = "high"
        sender = FakeSender(runner.HttpResult(200, api_response()), RuntimeError("synthetic failure"))
        manifest = {
            "run_id": "partial-run",
            "status": "running",
            "timestamp_started": runner.utc_now(),
            "timestamp_finished": None,
            "contract": {"categories": self.contract.categories, "priorities": self.contract.priorities},
            "pricing": {
                "source_or_version": "unit-test",
                "verification_date": "2026-09-20",
                "currency": "USD",
                "unit": "per 1,000,000 tokens",
                "input_usd": 1.0,
                "cached_read_usd": 0.5,
                "cache_write_usd": 1.25,
                "output_usd": 2.0,
            },
            "preflight": {},
            "execution": {"selected_case_count": 2},
        }
        with tempfile.TemporaryDirectory() as temp:
            run_dir = Path(temp) / "partial-run"
            final = runner.execute_run(
                [first, second],
                self.contract,
                self.pricing,
                runner.Limits(2, 6, Decimal("10")),
                manifest,
                run_dir,
                sender,
                sleep=lambda _: None,
            )
            self.assertEqual(final["execution"]["attempted_case_count"], 2)
            predictions = [json.loads(line) for line in (run_dir / "predictions.jsonl").read_text(encoding="utf-8").splitlines()]
            self.assertEqual(predictions[0]["status"], "succeeded")
            self.assertEqual(predictions[1]["error_code"], "AI_INTERNAL_ERROR")
            for name in ("manifest.json", "predictions.jsonl", "attempts.jsonl", "metrics.json", "cost.json"):
                self.assertTrue((run_dir / name).exists(), name)
            with self.assertRaises(FileExistsError):
                runner.execute_run(
                    [first], self.contract, self.pricing, runner.Limits(1, 3, Decimal("10")), manifest, run_dir, sender
                )


if __name__ == "__main__":
    unittest.main()
