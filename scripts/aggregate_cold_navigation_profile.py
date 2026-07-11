#!/usr/bin/env python3
"""Aggregate fresh-launch cold-navigation profile reports.

Usage:
  scripts/aggregate_cold_navigation_profile.py \
    --input build/cold_navigation_profile/runs \
    --output build/cold_navigation_profile/summary.json
"""

from __future__ import annotations

import argparse
import json
import statistics
from collections import defaultdict
from pathlib import Path
from typing import Any


METRIC_PATHS = (
    ("frame_count",),
    ("interaction_duration_us",),
    ("ui_build", "p95_us"),
    ("ui_build", "p99_us"),
    ("ui_build", "worst_us"),
    ("ui_build", "over_8_33ms_count"),
    ("ui_build", "over_16_67ms_count"),
    ("ui_build", "over_33ms_count"),
    ("ui_build", "over_50ms_count"),
    ("raster", "p95_us"),
    ("raster", "p99_us"),
    ("raster", "worst_us"),
    ("raster", "over_8_33ms_count"),
    ("raster", "over_16_67ms_count"),
    ("raster", "over_33ms_count"),
    ("raster", "over_50ms_count"),
    ("combined", "p95_us"),
    ("combined", "p99_us"),
    ("combined", "worst_us"),
    ("combined", "over_8_33ms_count"),
    ("combined", "over_16_67ms_count"),
    ("combined", "over_33ms_count"),
    ("combined", "over_50ms_count"),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def nested_value(payload: dict[str, Any], path: tuple[str, ...]) -> int | float | None:
    current: Any = payload
    for key in path:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current if isinstance(current, (int, float)) else None


def nested_assign(payload: dict[str, Any], path: tuple[str, ...], value: int | float) -> None:
    current = payload
    for key in path[:-1]:
        current = current.setdefault(key, {})
    current[path[-1]] = value


def scenario_score(median: dict[str, Any]) -> float:
    combined = median.get("combined", {})
    if not isinstance(combined, dict):
        return 0.0
    missed = combined.get("over_8_33ms_count", 0)
    p99 = combined.get("p99_us", 0)
    worst = combined.get("worst_us", 0)
    return float(missed) * 1000000 + float(p99) * 10 + float(worst)


def aggregate(reports: list[tuple[Path, dict[str, Any]]]) -> dict[str, Any]:
    scenarios: dict[str, list[tuple[Path, dict[str, Any]]]] = defaultdict(list)
    for report_path, report in reports:
        profile = report.get("profile")
        if not isinstance(profile, dict):
            continue
        scenario_map = profile.get("scenarios")
        if not isinstance(scenario_map, dict):
            continue
        for scenario_id, scenario in scenario_map.items():
            if isinstance(scenario_id, str) and isinstance(scenario, dict):
                scenarios[scenario_id].append((report_path, scenario))

    summary_scenarios: dict[str, Any] = {}
    ranking: list[dict[str, Any]] = []
    for scenario_id, runs in scenarios.items():
        median: dict[str, Any] = {}
        for path in METRIC_PATHS:
            values = [nested_value(scenario, path) for _, scenario in runs]
            values = [value for value in values if value is not None]
            if values:
                nested_assign(median, path, statistics.median(values))

        validity = {
            "final_state_reached_runs": sum(
                scenario.get("expected_final_state_reached") is True
                for _, scenario in runs
            ),
            "intermediate_frames_rendered_runs": sum(
                scenario.get("intermediate_frames_rendered") is True
                for _, scenario in runs
            ),
            "animated_runs": sum(
                scenario.get("is_animated") is True for _, scenario in runs
            ),
        }
        score = scenario_score(median)
        run_details = [
            {
                "report_file": str(path),
                "timeline_file": scenario.get("timeline_file"),
                "expected_final_state_reached": scenario.get(
                    "expected_final_state_reached"
                ),
                "intermediate_frames_rendered": scenario.get(
                    "intermediate_frames_rendered"
                ),
            }
            for path, scenario in runs
        ]
        summary_scenarios[scenario_id] = {
            "run_count": len(runs),
            "median": median,
            "validity": validity,
            "rank_score": score,
            "runs": run_details,
        }
        ranking.append({"scenario_id": scenario_id, "rank_score": score})

    ranking.sort(key=lambda item: item["rank_score"], reverse=True)
    for index, item in enumerate(ranking, start=1):
        item["rank"] = index

    return {
        "schema_version": 1,
        "report_count": len(reports),
        "scenarios": summary_scenarios,
        "ranking_worst_to_best": ranking,
    }


def write_markdown(summary: dict[str, Any], output_path: Path) -> None:
    lines = [
        "# Cold Navigation Profile Summary",
        "",
        "| Rank | Scenario | Median >8.33ms frames | Median p99 | Median worst |",
        "| ---: | --- | ---: | ---: | ---: |",
    ]
    scenarios = summary["scenarios"]
    for item in summary["ranking_worst_to_best"]:
        scenario = scenarios[item["scenario_id"]]
        combined = scenario["median"].get("combined", {})
        lines.append(
            "| {rank} | {id} | {missed} | {p99} us | {worst} us |".format(
                rank=item["rank"],
                id=item["scenario_id"],
                missed=combined.get("over_8_33ms_count", 0),
                p99=combined.get("p99_us", 0),
                worst=combined.get("worst_us", 0),
            )
        )
    output_path.write_text("\n".join(lines) + "\n")


def main() -> int:
    args = parse_args()
    report_paths = sorted(args.input.glob("**/report.json"))
    if not report_paths:
        raise SystemExit(f"No report.json files found below {args.input}")

    reports: list[tuple[Path, dict[str, Any]]] = []
    for path in report_paths:
        payload = json.loads(path.read_text())
        if not isinstance(payload, dict):
            raise SystemExit(f"{path} is not a JSON object")
        reports.append((path, payload))

    summary = aggregate(reports)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(summary, indent=2) + "\n")
    write_markdown(summary, args.output.with_suffix(".md"))
    print(f"Wrote {args.output}")
    print(f"Wrote {args.output.with_suffix('.md')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
