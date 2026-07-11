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


def scenario(*, missed_pct: int, p99: int, worst: int,
             frame_count: int = 10, consec: int = 0) -> dict:
    return {
        "expected_final_state_reached": True,
        "intermediate_frames_rendered": True,
        "is_animated": True,
        "frame_count": frame_count,
        "interaction_duration_us": 200000,
        "ui_build": {"p95_us": 2, "p99_us": p99, "worst_us": worst,
                     "over_8_33ms_count": missed_pct,
                     "over_8_33ms_pct": missed_pct,
                     "over_16_67ms_count": 0,
                     "over_33ms_count": 0, "over_50ms_count": 0,
                     "consecutive_missed_frames": consec},
        "raster": {"p95_us": 2, "p99_us": p99, "worst_us": worst,
                   "over_8_33ms_count": missed_pct,
                   "over_8_33ms_pct": missed_pct,
                   "over_16_67ms_count": 0,
                   "over_33ms_count": 0, "over_50ms_count": 0,
                   "consecutive_missed_frames": consec},
        "combined": {"p95_us": 2, "p99_us": p99, "worst_us": worst,
                     "over_8_33ms_count": missed_pct,
                     "over_8_33ms_pct": missed_pct,
                     "over_16_67ms_count": 0,
                     "over_33ms_count": 0, "over_50ms_count": 0,
                     "consecutive_missed_frames": consec},
    }


class AggregationTest(unittest.TestCase):
    def test_uses_medians_and_ranks_individual_worst_first(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            reports = [
                (root / "run-1" / "report.json", scenario(missed_pct=10, p99=10, worst=12)),
                (root / "run-2" / "report.json", scenario(missed_pct=90, p99=90, worst=120)),
                (root / "run-3" / "report.json", scenario(missed_pct=30, p99=30, worst=40)),
            ]
            payloads = []
            for path, slow in reports:
                path.parent.mkdir()
                payloads.append((path, {"profile": {"scenarios": {
                    "slow": slow,
                    "fast": scenario(missed_pct=0, p99=4, worst=5),
                }}}))

            summary = MODULE.aggregate(payloads)
            slow = summary["scenarios"]["slow"]
            self.assertEqual(slow["run_count"], 3)
            self.assertEqual(slow["median"]["combined"]["over_8_33ms_pct"], 30)
            self.assertEqual(slow["median"]["combined"]["p99_us"], 30)
            self.assertEqual(slow["category"], "individual")
            self.assertEqual(
                summary["ranking_individual_worst_to_best"][0]["scenario_id"], "slow"
            )
            self.assertIn("ranking_individual_worst_to_best", summary)
            self.assertIn("ranking_compound_worst_to_best", summary)

    def test_compound_journeys_ranked_separately(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "run-1" / "report.json"
            path.parent.mkdir()
            payload = {"profile": {"scenarios": {
                "drawer_open": scenario(missed_pct=50, p99=20, worst=30),
                "combined_cold_start_journey": scenario(
                    missed_pct=80, p99=100, worst=200, frame_count=195,
                ),
            }}}
            summary = MODULE.aggregate([(path, payload)])

            individual_ids = [r["scenario_id"]
                              for r in summary["ranking_individual_worst_to_best"]]
            compound_ids = [r["scenario_id"]
                            for r in summary["ranking_compound_worst_to_best"]]

            self.assertEqual(individual_ids, ["drawer_open"])
            self.assertEqual(compound_ids, ["combined_cold_start_journey"])
            self.assertEqual(
                summary["scenarios"]["combined_cold_start_journey"]["category"],
                "compound",
            )

    def test_zero_frame_scenario_ranks_highest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "run-1" / "report.json"
            path.parent.mkdir()
            payload = {"profile": {"scenarios": {
                "broken": scenario(missed_pct=0, p99=0, worst=0, frame_count=0),
                "smooth": scenario(missed_pct=0, p99=4, worst=5, frame_count=20),
            }}}
            summary = MODULE.aggregate([(path, payload)])
            self.assertEqual(
                summary["ranking_individual_worst_to_best"][0]["scenario_id"],
                "broken",
            )


if __name__ == "__main__":
    unittest.main()
