---
title: Coalesce weekly schedule state and isolate raster layers
date: 2026-07-12
type: fix
---

# Summary

The follow-up to PR #96 reduces the remaining weekly Schedule work observed
on a Pixel 8 Pro at 120 Hz. PR #96 already keeps the PageView and entry tree
stable during the 220 ms viewport transition; this change keeps equivalent
cache/refresh results from notifying the page and prevents refresh completions
from changing the settled page while a swipe is still active.

# State and refresh behavior

- `WeeklyScheduleViewModel` now publishes a versioned
  `VisibleWeeklyScheduleSnapshot`. The snapshot copies the visible entry
  sequence and compares render-relevant entry content, date range, and display
  geometry. Replacing a cache object with equivalent content therefore does
  not notify the weekly page.
- Visible refreshes and cache reads carry both the schedule-source generation
  and a visible-state request id. Results from an old source or an older page
  request can still finish safely, but cannot become visible state.
- The weekly page marks paging active on `ScrollStartNotification`. While the
  PageView is moving, visible cache/refresh results are reduced to the latest
  valid result for the currently visible week. The result is applied only after
  the settled page is known; results for a different settled week are dropped.
- Adjacent week prefetch and warmup continue to populate memory caches only.
  They do not notify or replace the visible schedule.

# Raster and layer boundaries

The existing card styling, shadows, translucent past overlay, grid, current
time indicator, interactions, and animations are unchanged. The paint tree now
has explicit boundaries for the grid, stable entry layer, labels, past
overlay, and current-time indicator. The grid itself separates static vertical
column lines from viewport-dependent horizontal hour lines, so the static
portion can be reused while the hour viewport changes.

These boundaries isolate the large translucent overlay and changing grid from
the stable entry layer. They are deliberately limited to layers with
independent invalidation inputs; no blanket boundary was added around the
whole schedule tree and no visual effect was removed.

# Telemetry

Frame jank detection now compares build and raster durations with the active
display refresh budget (`1000 / refreshRateHz`). It uses microsecond durations
so the 120 Hz 8.33 ms budget is not rounded to milliseconds. Detection remains
in the frame-timing callback and does not add work to Schedule render paths.

# Regression coverage

Schedule tests cover equivalent-state notification suppression, latest cache
then refresh result wins after paging settles, stale queued result rejection,
grid painter invalidation isolation, layer boundary presence, and refresh-rate
aware frame budgets. The existing PageView swipe, chevron, viewport animation,
entry identity, card layout, and current-time indicator tests remain in scope.

# Pixel 8 Pro results

Device conditions:

- Pixel 8 Pro in profile mode;
- 120 Hz display;
- Android animation scales at `1.0`;
- deterministic offline fixture data;
- three current-`v2` control runs and three final branch runs.

Median comparison:

| Scenario | Metric | Current `v2` | Final branch |
| --- | --- | ---: | ---: |
| Cold placeholder → populated | frames > 8.33 ms | 9.38% | 6.06% |
| First populated swipe | frames > 8.33 ms | 20.45% | 14.89% |
| First populated swipe | p99 | 32.33 ms | 25.85 ms |
| Short → tall transition | frames > 8.33 ms | 25.58% | 22.22% |
| Short → tall transition | p95 | 17.25 ms | 11.93 ms |
| Short → tall transition | frames > 16.67 ms | 3 | 1 |
| Settled populated swipe | frames > 8.33 ms | 22.92% | 12.24% |
| Settled populated swipe | consecutive misses | 3 | 1 |
| Database-cached navigation | frames > 8.33 ms | 17.95% | 7.20% |
| Database-cached navigation | raster frames > 8.33 ms | 11.11% | 1.57% |
| Rapid four-swipe burst | frames > 8.33 ms | 16.45% | 7.45% |
| Rapid four-swipe burst | p95 | 16.00 ms | 9.89 ms |
| Rapid four-swipe burst | consecutive misses | 3 | 1 |

The short-to-tall transition's raster-only over-budget percentage increased
from 9.30% to 17.78%, while its combined missed-frame rate, p95, p99, and
frames above 16.67 ms all improved. The retained layer boundaries therefore
reduce total interaction cost and tail latency, but that transition remains the
main raster-focused follow-up area.

All Schedule final-state and animation-progression checks passed in all three
runs. The only diagnostic warning was the independent Dates loading transition,
which is fixed by the separate Dates lazy-rendering PR.

# Validation

- full `flutter analyze` — clean;
- `flutter test test/schedule test/common/logging/performance_telemetry_test.dart`
  — 162 tests passed;
- three-run current-`v2` Pixel control;
- three-run final-branch Pixel diagnostic;
- existing PageView gesture, viewport-animation, cache, refresh, current-time,
  entry identity, and loading behavior retained;
- no animation duration, fixture data, or performance threshold was reduced.
