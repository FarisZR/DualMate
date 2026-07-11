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
    ("ui_build", "over_8_33ms_pct"),
    ("ui_build", "over_16_67ms_count"),
    ("ui_build", "over_33ms_count"),
    ("ui_build", "over_50ms_count"),
    ("ui_build", "consecutive_missed_frames"),
    ("raster", "p95_us"),
    ("raster", "p99_us"),
    ("raster", "worst_us"),
    ("raster", "over_8_33ms_count"),
    ("raster", "over_8_33ms_pct"),
    ("raster", "over_16_67ms_count"),
    ("raster", "over_33ms_count"),
    ("raster", "over_50ms_count"),
    ("raster", "consecutive_missed_frames"),
    ("combined", "p95_us"),
    ("combined", "p99_us"),
    ("combined", "worst_us"),
    ("combined", "over_8_33ms_count"),
    ("combined", "over_8_33ms_pct"),
    ("combined", "over_16_67ms_count"),
    ("combined", "over_33ms_count"),
    ("combined", "over_50ms_count"),
    ("combined", "consecutive_missed_frames"),
)

# Compound journeys (multi-screen sequences) are ranked in a separate
# category so that their larger absolute frame counts do not dominate the
# individual-animation ranking.
COMPOUND_PREFIXES = ("combined_", "journey_")


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


def is_compound(scenario_id: str) -> bool:
    return any(scenario_id.startswith(p) for p in COMPOUND_PREFIXES)


def scenario_score(median: dict[str, Any]) -> float:
    """Rank by percentage-over-budget, p99, worst-frame, and validity.

    The score prioritises:
      1. Percentage of frames above the 120 Hz budget (normalised severity).
      2. p99 latency (tail severity).
      3. Worst-frame latency.
      4. Consecutive missed frames (stall length).
      5. Validity penalty (final-state or intermediate-frame failures).
    """
    combined = median.get("combined", {})
    if not isinstance(combined, dict):
        return 0.0

    pct_over = combined.get("over_8_33ms_pct", 0)
    p99 = combined.get("p99_us", 0)
    worst = combined.get("worst_us", 0)
    consecutive = combined.get("consecutive_missed_frames", 0)
    frame_count = median.get("frame_count", 0)

    # Base score: weighted percentage over budget (primary signal).
    score = float(pct_over) * 100000

    # p99 and worst severity (secondary signal).
    score += float(p99) * 10
    score += float(worst)

    # Consecutive stalls indicate jank perceptible to users.
    score += float(consecutive) * 50000

    # Zero-frame measured transitions are severe: they indicate broken
    # attribution or a missing animation.
    if frame_count == 0:
        score += 100000000

    return score


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
    individual_ranking: list[dict[str, Any]] = []
    compound_ranking: list[dict[str, Any]] = []

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
            "category": "compound" if is_compound(scenario_id) else "individual",
            "runs": run_details,
        }

        ranking_entry = {"scenario_id": scenario_id, "rank_score": score}
        if is_compound(scenario_id):
            compound_ranking.append(ranking_entry)
        else:
            individual_ranking.append(ranking_entry)

    individual_ranking.sort(key=lambda item: item["rank_score"], reverse=True)
    compound_ranking.sort(key=lambda item: item["rank_score"], reverse=True)
    for index, item in enumerate(individual_ranking, start=1):
        item["rank"] = index
    for index, item in enumerate(compound_ranking, start=1):
        item["rank"] = index

    return {
        "schema_version": 2,
        "report_count": len(reports),
        "scenarios": summary_scenarios,
        "ranking_individual_worst_to_best": individual_ranking,
        "ranking_compound_worst_to_best": compound_ranking,
    }


def write_markdown(summary: dict[str, Any], output_path: Path) -> None:
    lines = [
        "# Cold Navigation Profile Summary",
        "",
        "## Individual Scenarios",
        "",
        "| Rank | Scenario | % >8.33ms | p99 | worst | consec |",
        "| ---: | --- | ---: | ---: | ---: | ---: |",
    ]
    scenarios = summary["scenarios"]

    def _ranking_rows(ranking_key: str, header: str) -> None:
        ranking = summary.get(ranking_key, [])
        if not ranking:
            return
        lines.extend(["", f"## {header}", "",
                      "| Rank | Scenario | % >8.33ms | p99 | worst | consec |",
                      "| ---: | --- | ---: | ---: | ---: | ---: |"])
        for item in ranking:
            scenario = scenarios[item["scenario_id"]]
            combined = scenario["median"].get("combined", {})
            lines.append(
                "| {rank} | {id} | {pct}% | {p99} us | {worst} us | {consec} |".format(
                    rank=item["rank"],
                    id=item["scenario_id"],
                    pct=combined.get("over_8_33ms_pct", 0),
                    p99=combined.get("p99_us", 0),
                    worst=combined.get("worst_us", 0),
                    consec=combined.get("consecutive_missed_frames", 0),
                )
            )

    for item in summary.get("ranking_individual_worst_to_best", []):
        scenario = scenarios[item["scenario_id"]]
        combined = scenario["median"].get("combined", {})
        lines.append(
            "| {rank} | {id} | {pct}% | {p99} us | {worst} us | {consec} |".format(
                rank=item["rank"],
                id=item["scenario_id"],
                pct=combined.get("over_8_33ms_pct", 0),
                p99=combined.get("p99_us", 0),
                worst=combined.get("worst_us", 0),
                consec=combined.get("consecutive_missed_frames", 0),
            )
        )

    _ranking_rows("ranking_compound_worst_to_best", "Compound Journeys")

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
