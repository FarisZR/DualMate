---
title: Loaded cold-navigation performance harness
date: 2026-07-10
type: test
---

# Purpose

`integration_test/aggressive_cold_navigation_performance_test.dart` is the
profile-mode entry point for the full cold-start stress run and focused diagnostics. It
seeds deterministic data through the app's SQLite and secure-storage paths:

- populated Schedule weeks with short and tall hour ranges;
- an intentionally unseeded Schedule week that must render through the local
  refresh-required path;
- Canteen days with varied meal counts;
- cached Rapla-style important-event sections across the normal Dates paging
  window for a real list-scroll workload;
- the existing fully populated Dualis demo account.
- two timetable sources with at least 160 cached modules for customization.

The default full run is `stress`: one cold launch followed by three continuous
rounds across Schedule, customization, Canteen, Dates and Dualis. Each round
includes 92 real flings, grouped as four forward and four reverse gestures.
Gestures interrupt active ballistic motion and screen transitions. They begin
as soon as the necessary controls/content exist; the full run has no warm-up
journey, no frame-scheduler-idle waits, and no per-section frame-drain pauses.
It also toggles modules, rapidly expands/collapses groups, saves selections,
reopens customization, and switches Dualis tabs during the same journey.

`stress_workload` in each report records the actual gesture count, phase
boundaries, scroll-progression checks and time to the first gesture after app
startup. The standard three repetitions are three whole cold-launch journeys,
not separate cold runs for each screen.

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

Controls the workload. Separate screen targets are opt-in diagnostics:

- `stress` (default): The entire continuous cold-launch stress journey above.
- `schedule`: Cold launch to first populated Schedule interaction and swipe.
- `customization`: Cold launch through the real timetable toolbar to two sources
  and 160 cached modules, then row selection, expansion, real scrolling,
  selecting from the added source, saving/applying, and reopening saved choices.
- `canteen`: Cold launch to first Canteen navigation and populated content.
- `dates`: Cold launch to first Dates navigation and populated content.
- `dualis`: Cold launch to first Dualis navigation and populated content.
- `combined`: The full secondary regression journey
  (Schedule -> Canteen -> Dates -> Dualis).
- `all`: All diagnostic scenarios in one sequential process, with attribution
  pauses. This is not the default full stress run.

Every full stress repetition launches a fresh process once. All screens then
share its startup work and ongoing interaction load.

# Frame attribution (Issue 1)

The full stress journey uses one uninterrupted timing collection spanning all
screens. Frames predating the action are excluded using the monotonic
`FramePhase.buildStart` timestamp. Delivery is drained once, after the entire
journey. Focused diagnostic targets drain batches between individual scenarios
to avoid attributing old batches to a later isolated interaction.

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
finished. These waits are only used by focused diagnostics, not the default
continuous stress journey.

# Run on a phone

Connect the Android device in its normal display mode, with Android and Flutter
animation scales at normal speed, then run:

```bash
PERF_RUNS=3 scripts/run_cold_navigation_perf_suite.sh
```

The script uses `adb` to select the physical phone, checks all three Android
animation scales are `1.0`, force-stops the perf app before every launch, and
runs the Flutter integration test in profile mode with `--no-dds`.

The test explicitly uses `LiveTestWidgetsFlutterBindingFramePolicy.fullyLive`
so animations render at the display cadence between test pumps. The inherited
test-driven frame policy can visibly step animations and undersample them.
Unset Android animation-scale settings use the platform's normal 1.0 default;
the harness accepts that default without changing device settings.
During a run it keeps a plugged-in device awake, restoring the previous
`stay_on_while_plugged_in` value on exit. Flutter's synthetic gestures do not
reset Android's inactivity timer, so an unattended long run would otherwise
lose its surface when the display sleeps.

On tablets, destination selection uses the permanent navigation panel. The four
drawer-only opening and closing scenarios are recorded under
`inapplicable_scenarios`, with a reason, rather than reported as passed
animations. Phone runs continue to verify real drawer translation.

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
