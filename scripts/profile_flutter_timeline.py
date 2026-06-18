#!/usr/bin/env python3
"""Summarize Flutter VM-service timeline events.

Usage:
  scripts/profile_flutter_timeline.py /tmp/timeline.json [/tmp/other.json ...]
"""

from __future__ import annotations

import json
import statistics
import sys
from collections import defaultdict
from pathlib import Path


DEFAULT_EVENTS = (
    "Frame",
    "Animator::BeginFrame",
    "BUILD",
    "LAYOUT",
    "LAYOUT (root)",
    "PAINT",
    "PAINT (root)",
    "GPURasterizer::Draw",
    "Rasterizer::DoDraw",
    "LayerTree::Preroll",
    "LayerTree::Paint",
    "Canvas::saveLayer",
    "SceneDisplayLag",
    "schedule.refresh",
    "schedule.cache",
)


def percentile(values: list[float], percent: float) -> float:
    if not values:
        return 0.0
    values = sorted(values)
    index = min(len(values) - 1, round((len(values) - 1) * percent))
    return values[index]


def load_events(path: Path) -> list[dict]:
    payload = json.loads(path.read_text())
    if "result" in payload and "traceEvents" in payload["result"]:
        return payload["result"]["traceEvents"]
    if "traceEvents" in payload:
        return payload["traceEvents"]
    raise SystemExit(f"No traceEvents found in {path}")


def collect_durations(events: list[dict]) -> dict[str, list[float]]:
    durations: dict[str, list[float]] = defaultdict(list)
    open_events: dict[tuple[object, object, object], list[int]] = defaultdict(list)

    for event in events:
        name = event.get("name")
        phase = event.get("ph")
        timestamp = event.get("ts")
        if not name:
            continue

        if phase == "X" and "dur" in event:
            durations[name].append(event["dur"] / 1000.0)
            continue

        if phase == "B" and timestamp is not None:
            open_events[(name, event.get("tid"), None)].append(timestamp)
            continue

        if phase == "E" and timestamp is not None:
            key = (name, event.get("tid"), None)
            if open_events[key]:
                start = open_events[key].pop()
                durations[name].append((timestamp - start) / 1000.0)
            continue

        if phase == "b" and timestamp is not None:
            open_events[(name, event.get("tid"), event.get("id"))].append(
                timestamp,
            )
            continue

        if phase == "e" and timestamp is not None:
            key = (name, event.get("tid"), event.get("id"))
            if open_events[key]:
                start = open_events[key].pop()
                durations[name].append((timestamp - start) / 1000.0)

    return durations


def collect_spans(events: list[dict]) -> list[tuple[str, int, int, float]]:
    spans: list[tuple[str, int, int, float]] = []
    open_events: dict[tuple[object, object, object], list[int]] = defaultdict(list)

    for event in events:
        name = event.get("name")
        phase = event.get("ph")
        timestamp = event.get("ts")
        if not name or timestamp is None:
            continue

        if phase == "X" and "dur" in event:
            duration = event["dur"]
            spans.append((name, timestamp, timestamp + duration, duration / 1000.0))
            continue

        if phase == "B":
            open_events[(name, event.get("tid"), None)].append(timestamp)
            continue

        if phase == "E":
            key = (name, event.get("tid"), None)
            if open_events[key]:
                start = open_events[key].pop()
                spans.append((name, start, timestamp, (timestamp - start) / 1000.0))
            continue

        if phase == "b":
            open_events[(name, event.get("tid"), event.get("id"))].append(timestamp)
            continue

        if phase == "e":
            key = (name, event.get("tid"), event.get("id"))
            if open_events[key]:
                start = open_events[key].pop()
                spans.append((name, start, timestamp, (timestamp - start) / 1000.0))

    return spans


def print_summary(durations: dict[str, list[float]], event_names: tuple[str, ...]):
    print("event,n,p50_ms,p90_ms,p95_ms,max_ms,mean_ms,>8.33ms,>16.67ms")
    for name in event_names:
        values = durations.get(name, [])
        if not values:
            continue
        print(
            ",".join(
                [
                    name,
                    str(len(values)),
                    f"{statistics.median(values):.2f}",
                    f"{percentile(values, 0.90):.2f}",
                    f"{percentile(values, 0.95):.2f}",
                    f"{max(values):.2f}",
                    f"{statistics.mean(values):.2f}",
                    str(sum(value > 8.33 for value in values)),
                    str(sum(value > 16.67 for value in values)),
                ],
            ),
        )


def print_top_frames(spans: list[tuple[str, int, int, float]], limit: int = 8):
    frames = sorted(
        (span for span in spans if span[0] == "Frame"),
        key=lambda span: span[3],
        reverse=True,
    )
    if not frames:
        return

    interesting = {
        "BUILD",
        "LAYOUT",
        "LAYOUT (root)",
        "PAINT",
        "PAINT (root)",
        "GPURasterizer::Draw",
        "Rasterizer::DoDraw",
        "SceneDisplayLag",
        "schedule.refresh",
        "schedule.cache",
    }

    print("top_frames_over_8.33ms")
    print("frame_ms,start_ts,end_ts,overlapping_hot_spans")
    for _, start, end, duration in frames[:limit]:
        hot_spans: list[str] = []
        for name, span_start, span_end, span_duration in spans:
            if name not in interesting:
                continue
            if span_end < start or span_start > end:
                continue
            if span_duration < 1.0 and name not in {"schedule.refresh", "schedule.cache"}:
                continue
            hot_spans.append(f"{name}:{span_duration:.2f}ms")
        print(
            f"{duration:.2f},{start},{end},{' | '.join(hot_spans[:8])}",
        )


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2

    for index, arg in enumerate(sys.argv[1:]):
        path = Path(arg)
        events = load_events(path)
        durations = collect_durations(events)
        spans = collect_spans(events)
        if index:
            print()
        print(f"path={path}")
        print(f"events={len(events)}")
        print_summary(durations, DEFAULT_EVENTS)
        print_top_frames(spans)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
