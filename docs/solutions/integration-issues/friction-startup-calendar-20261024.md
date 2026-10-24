---
title: Resolve startup and calendar friction and reconcile harness fixes
date: 2026-10-24
type: bugfix
issues: [128, 138, 139, 140, 141, 144, 150]
tags: [startup, provider, canteen, dst, testing, performance]
---

# Causes and fixes

## Startup notifications (#128)

`SchedulePage.didChangeDependencies` initialized the source synchronously while
mounting the provider subtree. The performance-fixture path immediately completes
setup and notifies listeners, causing a framework assertion during construction.
A regression widget test with a visible navigation-index provider reproduces
`setState() or markNeedsBuild() called during build` before the fix.

Initial, dependency-change and visibility-triggered work now share a deduplicated
post-frame callback. It checks mounting and current visibility before starting
work; hidden pages still defer weekly initialization. The view model retains its
normal idempotent initialization and cancellation behavior.

## Canteen dates and fixtures (#138, #150)

Elapsed durations are unsuitable for advancing local calendar dates. In
Europe/Berlin, `DateTime(2026, 10, 24).add(Duration(days: 2))` is Sunday at 23:00,
not Monday midnight. Advancing a week from 19 October could therefore prefetch
Sunday 25 October and normalize it back to the current week. This also explains
why tests with preloaded content lost it during adjacent-week refreshes.

The canteen page, view model, provider, render state, background updater, API
adapter and daily database query now use calendar-day arithmetic. Shared
`toMonday` uses the same operation; `addDays` preserves UTC and subsecond fields.
Freshness windows continue to measure elapsed durations.

The view model accepts a clock for today's date, shared by the page. Paging
fixtures use a fixed Tuesday instead of the execution date. Separate cases cover
Friday-to-Monday paging and Saturday/Sunday startup around both 2026 DST changes.
Database tests check the actual 23-hour and 25-hour daily query bounds.

## Existing harness fixes (#139, #140, #141, #144)

The first three fixes were already merged in #137, and video export in #143:

- Device performance tests explicitly select `fullyLive` frame scheduling.
- Tablet navigation selects the permanent panel; drawer-only animation checks
  are marked inapplicable rather than counted as passed animations.
- The suite wakes the plugged-in device and restores its original
  `stay_on_while_plugged_in` value on exit.
- The visual driver's response-data callback exports recordings before Flutter
  calls `exit`, including failed tests via `writeResponseOnFailure`.

Video cleanup was checked in host subprocesses against Flutter 3.47.8's actual
extended integration driver, injecting a result driver and an ADB recording stub.
Both success and failure exported the recording before process exit and removed
the remote stub. A finally-only negative control reproduced the missing export.
This is a lifecycle test, not a native video capture: the connected Huawei image
does not include Android's `screenrecord` executable.

# Validation

- Flutter 3.47.8 / Dart 3.13.7, matching CI.
- Regression tests were observed failing before the relevant fixes.
- `TZ=Europe/Berlin flutter test --no-pub`: 655 tests passed.
- Focused UTC date, repository and canteen paging tests: 27 passed.
- Fixture-enabled startup regression: passed.
- `flutter analyze` and the repository's complexity check: clean.
- Python performance-report aggregation tests: 4 passed.
- Android `:app:testDebugUnitTest`: 23 passed.

CI runs the focused calendar tests explicitly under `TZ=Europe/Berlin` and the
startup regression with `PERF_TEST_OFFLINE_FIXTURES=true`, in addition to the
normal suite. A UTC-only run cannot exercise the local DST transitions, and
fixture setup has different completion timing from ordinary source setup.

## Physical-device performance

The unchanged `de7cc6e` control and the candidate each completed three fresh
profile-mode stress journeys on the Huawei MRDI_W09 (Android 12/API 31). Every
journey exercised Schedule, customization, Canteen, Dates and Dualis over three
rounds. All six runs reached their expected final states, rendered intermediate
animation frames and passed every animation progression check.

Three-run medians for the complete journey:

| Metric | Control | Candidate |
| --- | ---: | ---: |
| Frames | 8,008 | 7,990 |
| Combined p95 | 6.041 ms | 6.213 ms |
| Combined p99 | 13.748 ms | 12.518 ms |
| Worst frame | 33.680 ms | 33.498 ms |
| Frames over 8.33 ms | 1.90% | 1.71% |
| Frames over 50 ms | 0 | 0 |
| Longest run over 8.33 ms | 8 | 5 |

The small p95 change is 0.172 ms; tail latency and the proportion of frames over
budget improved. There is no material regression in this comparison. These are
measurements on this tablet, not evidence about every supported phone.

Both complete suites restored `stay_on_while_plugged_in` from their temporary
value of `7` to the original `0`. The screen stayed awake during the runs; the
user's screen timeout and animation scales were preserved. Full local reports
are under `build/friction-validation/{baseline,candidate}/`.

The isolated debug APK was installed and launched with the `android` CLI and
fixture startup overrides. Three separate processes completed base/root startup
and rendered the populated Schedule. Their process-filtered logcat captures
contained no Flutter assertion, `markNeedsBuild` error or fatal exception. Local
logs and a native screenshot are in
`build/friction-validation/debug-startup/`. Only the separate
`com.fariszr.dualmate.perf` package was installed and exercised.

A separate profile-mode Canteen journey also passed using a phone-sized
1080×1920 / 440 dpi window on the same physical tablet, exercising the modal
drawer path. This is a phone-layout check, not a second physical device. The
original 1840×2800 size override and 306 dpi density override were restored,
along with the original charging wake policy and unchanged 600,000 ms screen
timeout. Its report is in `build/friction-validation/phone-layout/`.

# Relationship to the Fable report

Issue #131 remains open. These changes resolve the concrete friction reports;
they do not replace its broader architectural review. Fixture injection,
startup ownership and splitting the large harness remain useful follow-ups.
The report's proposed deletion of the canteen test helper is incorrect: seven
test files import it, including on its audited commit. Replacing the idle
coordinator also requires preserving interaction gating, serialization,
cancellation and freedom from starvation by unrelated repeating animations.
