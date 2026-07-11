---
title: Loaded cold-navigation performance harness
date: 2026-07-10
type: test
---

# Purpose

`integration_test/aggressive_cold_navigation_performance_test.dart` is the
profile-mode entry point for loaded-content cold-navigation diagnostics. It
seeds deterministic data through the app's SQLite and secure-storage paths:

- populated Schedule weeks with short and tall hour ranges;
- an intentionally unseeded Schedule week that must render through the local
  refresh-required path;
- Canteen days with varied meal counts;
- cached Rapla-style important-event sections across the normal Dates paging
  window for a real list-scroll workload;
- the existing fully populated Dualis demo account.

The suite requires `PERF_TEST_OFFLINE_FIXTURES=true`. That opt-in define keeps
the production code path unchanged while configuring a valid local Schedule
source before the UI is built, preventing fixture runs from issuing Canteen or
Dates refresh requests, registering Android background work, or delivering
Sentry events for deliberate harness failures. All data shown in a measured interaction is therefore local and
deterministic.

The fixture first validates the configured Schedule source, then replaces only
the fixture run's remote source with a deterministic local source. This keeps
the normal visible refresh pipeline measurable without external I/O.

# Modes and targets

## PERF_PROFILE_MODE

Controls the measurement overhead:

- `ranking` (default): Low-overhead frame-measurement pass. No VM timeline
  tracing. Frame timings are collected and attributed by wall-clock timestamp.
  Use this for ranking scenarios by severity.
- `diagnostic`: Individual scenarios with full VM timeline tracing. Produces
  large timeline files (~10 MB each). Use only for selected hotspots after
  ranking identifies them.
- `combined`: Single end-to-end journey with timeline tracing. Use as a
  secondary stress test.

## PERF_TARGET

Controls which fresh-process cold-start scenario runs:

- `schedule`: Cold launch to first populated Schedule interaction and swipe.
- `canteen`: Cold launch to first Canteen navigation and populated content.
- `dates`: Cold launch to first Dates navigation and populated content.
- `dualis`: Cold launch to first Dualis navigation and populated content.
- `combined`: The full secondary regression journey
  (Schedule -> Canteen -> Dates -> Dualis).
- `all` (default): All diagnostic scenarios in one sequential process.

Each target except `all` and `combined` launches a genuine fresh process so
the measured interaction reflects real first-use, not a warm cache.

# Frame attribution (Issue 1)

Frames are assigned to scenarios using wall-clock timestamp boundaries, not
list-position slicing. The recorder records start/end microsecond timestamps
for each scenario. After all scenarios complete, it pumps several frames to
drain any batched FrameTiming delivery, then assigns each `FrameTiming` whose
`timestampMicroseconds` falls within a scenario's [start, end) window.

A scenario with zero assigned frames despite reaching its final state
invalidates the run.

# Real gestures (Issue 4)

Primary swipe and scroll scenarios use real fling gestures
(`tester.flingFrom`) rather than controller-driven `animateToPage`. This
exercises the full pointer handling, drag, release velocity, gesture
recognition, and scroll physics pipeline. Controller-driven transitions are
not used as primary scenarios.

Schedule page changes commit through the normal `onPageChanged` callback
instead of directly calling the view model.

# Animation verification (Issue 3)

Animation-specific scenarios sample intermediate visual state across frames:

- Drawer open: drawer width sampled during animation.
- Schedule short-to-tall: entry height sampled during transition.
- Canteen meal-count transition: content height sampled.
- Loading transitions: widget count/visibility sampled.

A transition that jumps directly from initial to final state without
progressive change is reported as invalid.

# Isolated application ID (Issue 6)

Performance runs install the profile APK under
`com.fariszr.dualmate.perf` so the benchmark cannot remove or overwrite a
developer's actual DualMate installation and data.

# Settled state (Issue 11)

`frame_scheduler_idle` (formerly `settled`) interactions use three consecutive
idle frames after loaded content. This only guarantees the Flutter frame
scheduler was idle, not that background services, isolates, or timers have
finished.

# Run on a phone

Connect the Android phone in its normal 120 Hz mode, with Android and Flutter
animation scales at normal speed, then run:

```bash
PERF_RUNS=3 scripts/run_cold_navigation_perf_suite.sh
```

The script uses `adb` to select the physical phone, checks all three Android
animation scales are `1.0`, force-stops the perf app before every launch, and
runs the Flutter integration test in profile mode with `--no-dds`.

# Results

Each fresh launch writes:

```text
build/aggressive_cold_navigation/runs/<target-run>/report.json
build/aggressive_cold_navigation/runs/<target-run>/timelines/<scenario>.json
```

`summary.json` and `summary.md` aggregate per-scenario metrics using medians
and rank scenarios from worst to best. Individual animations and compound
journeys are ranked in separate categories. Ranking uses percentage-over-budget,
p99, worst-frame severity, consecutive missed frames, and validity status.

Run an individual saved trace through the existing timeline reader for
span-level detail:

```bash
python3 scripts/profile_flutter_timeline.py \
  build/aggressive_cold_navigation/runs/diagnostic-01/timelines/<scenario>.json
```

`cold-loaded` interactions are measured immediately after the relevant cached
content is first rendered. `frame_scheduler_idle` variants use three
consecutive idle frames after the same loaded state, allowing a report to
distinguish startup contention from an intrinsically janky animation.
