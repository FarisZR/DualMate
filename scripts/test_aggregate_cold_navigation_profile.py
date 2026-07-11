#!/usr/bin/env python3
"""Regression test for cold-navigation median aggregation."""

import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("aggregate_cold_navigation_profile.py")
SPEC = importlib.util.spec_from_file_location("profile_aggregation", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def scenario(*, missed: int, p99: int, worst: int) -> dict:
    return {
        "expected_final_state_reached": True,
        "intermediate_frames_rendered": True,
        "is_animated": True,
        "frame_count": 10,
        "interaction_duration_us": 200000,
        "ui_build": {"p95_us": 2, "p99_us": p99, "worst_us": worst,
                     "over_8_33ms_count": missed, "over_16_67ms_count": 0,
                     "over_33ms_count": 0, "over_50ms_count": 0},
        "raster": {"p95_us": 2, "p99_us": p99, "worst_us": worst,
                   "over_8_33ms_count": missed, "over_16_67ms_count": 0,
                   "over_33ms_count": 0, "over_50ms_count": 0},
        "combined": {"p95_us": 2, "p99_us": p99, "worst_us": worst,
                     "over_8_33ms_count": missed, "over_16_67ms_count": 0,
                     "over_33ms_count": 0, "over_50ms_count": 0},
    }


class AggregationTest(unittest.TestCase):
    def test_uses_medians_and_ranks_worst_first(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            reports = [
                (root / "run-1" / "report.json", scenario(missed=1, p99=10, worst=12)),
                (root / "run-2" / "report.json", scenario(missed=9, p99=90, worst=120)),
                (root / "run-3" / "report.json", scenario(missed=3, p99=30, worst=40)),
            ]
            payloads = []
            for path, slow in reports:
                path.parent.mkdir()
                payloads.append((path, {"profile": {"scenarios": {
                    "slow": slow,
                    "fast": scenario(missed=0, p99=4, worst=5),
                }}}))

            summary = MODULE.aggregate(payloads)
            slow = summary["scenarios"]["slow"]
            self.assertEqual(slow["run_count"], 3)
            self.assertEqual(slow["median"]["combined"]["over_8_33ms_count"], 3)
            self.assertEqual(slow["median"]["combined"]["p99_us"], 30)
            self.assertEqual(summary["ranking_worst_to_best"][0]["scenario_id"], "slow")


if __name__ == "__main__":
    unittest.main()
