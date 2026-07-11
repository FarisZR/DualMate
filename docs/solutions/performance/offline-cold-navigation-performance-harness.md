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

The diagnostic mode records individual loaded Schedule, drawer, Canteen, Dates,
and Dualis scenarios. The combined mode records the full secondary regression
journey:

```text
Schedule -> drawer -> Canteen -> drawer -> Dates -> drawer -> Dualis
```

Every scenario gets its own VM timeline key (`scenario:<id>`), JSON result, and
final-state assertion. Animated scenarios require observed intermediate frames;
a direct transition to the end state is reported as invalid rather than smooth.

# Run On A Phone

Connect the Android phone in its normal 120 Hz mode, with Android and Flutter
animation scales at normal speed, then run:

```bash
PERF_RUNS=3 scripts/run_cold_navigation_perf_suite.sh
```

The script uses `adb` to select the physical phone, checks all three Android
animation scales are `1.0`, force-stops the app before every launch, and runs
the Flutter integration test in profile mode with `--no-dds`. Flutter's
`traceAction` opens its VM-service socket from the app process, so the harness
waits for that local socket to accept connections before tracing. This is a
readiness condition, not a measured delay. The runner does not alter device
settings or disable animations.

# Results

Each fresh launch writes:

```text
build/aggressive_cold_navigation/runs/<mode-run>/report.json
build/aggressive_cold_navigation/runs/<mode-run>/timelines/<scenario>.json
```

`summary.json` and `summary.md` aggregate per-scenario metrics using medians
and rank the scenarios from worst to best. A scenario result contains total
frame count, build/UI and raster duration arrays, p95/p99, worst build/raster,
counts above 8.33/16.67/33/50 ms, interaction duration, final-state status,
and intermediate-frame evidence. Run an individual saved trace through the
existing timeline reader for span-level detail:

```bash
python3 scripts/profile_flutter_timeline.py \
  build/aggressive_cold_navigation/runs/diagnostic-01/timelines/<scenario>.json
```

`cold-loaded` interactions are measured immediately after the relevant cached
content is first rendered. `settled` variants use three consecutive idle frames
after the same loaded state, allowing a report to distinguish startup contention
from an intrinsically janky animation.
