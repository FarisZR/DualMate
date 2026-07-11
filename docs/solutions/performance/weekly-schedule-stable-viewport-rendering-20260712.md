---
title: Keep weekly schedule entry trees stable during viewport animation
date: 2026-07-12
type: fix
---

# Summary

Pixel 8 Pro profiling at 120 Hz showed that the first populated weekly Schedule
swipe missed roughly one quarter of its frames. The horizontal page movement was
not the main cost. After the swipe committed, the short-to-tall hour-range
animation rebuilt and laid out the weekly calendar tree on every animation tick.

This change keeps the current PageView interaction and 220 ms hour viewport
animation, while moving viewport-independent preparation out of animation
frames. Schedule entry widgets now remain stable and a lightweight layout
delegate updates only their geometry as the visible hour range interpolates.

# Findings

1. `TweenAnimationBuilder` rebuilt the fixed hour axis, weekly pager, schedule
   pages, entry cards, and overlay layers for every viewport animation frame.
2. Entry overlap calculation regrouped and sorted the same week repeatedly even
   though the schedule content had not changed.
3. Reconstructing entry cards during the height animation increased main-isolate
   build pressure on the Pixel 8 Pro.
4. Updating every cached PageView page from one viewport notifier multiplied the
   work during the transition.
5. The first cache implementation reused prepared data by `Schedule` identity,
   but `Schedule` is mutable. In-place entry list changes could therefore leave
   stale prepared geometry visible.

# Changes

## Prepared weekly render data

- Added `ScheduleRenderData`, an immutable per-week snapshot containing:
  - normalized display range,
  - displayed day count,
  - entries grouped by day,
  - precomputed overlap columns.
- Cached prepared data per week and schedule snapshot instead of recalculating
  overlap alignment during viewport animation.
- Limited the page cache to seven weeks.

## Stable viewport animation

- Replaced the broad tween builder with `_AnimatedWeeklyViewport`, which owns a
  `ValueNotifier<ScheduleViewport>`.
- Kept the `PageView` subtree stable while the viewport interpolates.
- Only the currently visible week listens to animation ticks; offscreen weeks
  use the final target viewport immediately.
- Preserved:
  - interactive finger-following PageView behavior,
  - fixed hour axis,
  - 220 ms ease-out viewport transition,
  - loading indicator behavior,
  - entry taps and detail sheet behavior,
  - current-week navigation and cached week flow.

## Stable entry widgets

- Entry cards are created once for a prepared week and hosted in
  `CustomMultiChildLayout`.
- `_ScheduleEntryLayoutDelegate` recalculates only entry rectangles when the
  viewport changes.
- Card contents, labels, and overlap preparation no longer rebuild per animation
  tick.
- Grid, past overlay, and current-time indicator continue to update with the
  viewport because their geometry genuinely changes.

## Cache invalidation hardening

- Cached page data snapshots the exact `ScheduleEntry` identity and order
  sequence.
- Cache lookup validates that sequence before reusing prepared data.
- Add, remove, reorder, or replacement mutations on the same mutable `Schedule`
  instance invalidate the render snapshot.
- Render-affecting `ScheduleEntry` fields are immutable, so this avoids hashing
  all entry content on every widget build while still detecting relevant
  in-place list mutations.
- Removed the unused identity-only `ScheduleRenderData.matches` helper.

## Render-path telemetry

- Removed per-page `PerformanceTelemetry.measureSync` work from the PageView
  item builder. Performance diagnostics remain at coarser operation boundaries
  rather than creating spans while widgets are being constructed.

# Regression coverage

`weekly_schedule_page_swipe_test.dart` now verifies that:

- the hour viewport still animates instead of jumping;
- the same PageView widget remains mounted through animation ticks;
- prepared overlap data is not regenerated during the animation;
- the same `ScheduleEntryWidget` instances remain mounted through the
  transition;
- in-place mutation of the cached `Schedule.entries` list invalidates prepared
  data and renders the new entry;
- real drag progress, committed week navigation, chevrons, and current-week
  controls retain their existing behavior.

The static preparation hook used by the tests is assigned inside the
cleanup-protected `try` block and reset in `finally`, preventing leakage into
later tests if setup fails.

# Pixel 8 Pro performance results

Device conditions:

- Pixel 8 Pro (`39181FDJG006DP`)
- profile mode
- 120 Hz display
- Android animation scales at `1.0`
- deterministic offline Schedule fixture
- three runs before and three runs after

Median comparison:

| Scenario | Metric | `v2` baseline | Final PR |
| --- | --- | ---: | ---: |
| Cold placeholder to populated | frames over 8.33 ms | 9.38% | 9.38% |
| First populated week swipe | frames over 8.33 ms | 25.00% | 14.58% |
| First populated week swipe | build frames over 8.33 ms | 18.18% | 4.08% |
| First populated week swipe | p95 | 16.84 ms | 11.73 ms |
| First populated week swipe | p99 | 29.83 ms | 25.62 ms |
| First populated week swipe | consecutive missed frames | 6 | 2 |

The CodeRabbit cache-safety follow-up did not reduce the improvement. Its final
three-run median was slightly better than the pre-review PR measurement.

# Validation

- `flutter analyze`
- `flutter test test/schedule`
  - 154 tests passed after the review follow-up.
- Three-run Schedule profile comparison on the Pixel 8 Pro.
- Full loaded diagnostic profile journey on the Pixel 8 Pro.
  - all Schedule final-state and animation-progression checks passed;
  - rapid Schedule burst and cached/refresh-required navigation remained valid.
- Standard profile APK installed and launched for manual testing.

# Remaining observations

- The improvement primarily removes build-side pressure. Some frames still miss
  the 8.33 ms budget due to raster work from dense cards, grid/overlay painting,
  and full-page movement.
- Cold placeholder-to-populated performance is effectively unchanged, which is
  expected because initial content still has to construct the entry tree once.
- Further work should use Pixel traces to target raster invalidation and layer
  reuse without removing shadows, overlays, or animations globally.
- The broader diagnostic suite still reports the existing Dates loading-to-rows
  progression issue; that is unrelated to this Schedule-only change.
