---
module: Schedule UI
date: 2026-02-11
problem_type: performance_issue
component: weekly_schedule
symptoms:
  - "Weekly swipe felt like a trigger (snap after release) instead of direct manipulation"
  - "Y-axis moved with horizontal drag, making transitions feel unstable"
  - "High-refresh phones (Pixel 8 Pro) showed more visible scroll jank than tablet devices"
root_cause: gesture_and_render_pipeline_churn
resolution_type: code_fix
severity: high
tags: [flutter, pageview, animation, schedule, jank, performance, pixel8pro]
---

# Solution: Interactive Weekly Swipe With Fixed Y-Axis and Reduced High-Refresh Jank

## Problem Symptom
- Horizontal swipe in weekly schedule did not visually track the finger; the next week appeared mostly after lift.
- Vertical hour axis moved during horizontal paging, which made the interaction feel noisy.
- On Pixel 8 Pro, scrolling felt choppier than on the tablet, especially around week transitions.

## Root Cause
1. Week navigation relied on swipe-threshold behavior instead of true page-position-driven rendering.
2. The schedule grid and Y-axis were rendered as one moving surface, so axis movement competed with swipe perception.
3. Hot-path rebuild pressure was too high on high-refresh displays due to:
   - rebuilds after prefetch completion,
   - frequent frame/log telemetry,
   - verbose provider logs during interaction paths.

## Implemented Solution

### 1. True Interactive Weekly Paging
- Replaced trigger-like swipe behavior with `PageView` ring paging (previous/current/next).
- Drag now directly drives page position, so halfway drag shows halfway next week.
- Re-centered pager after settle to keep memory and layout costs bounded.

### 2. Fixed Y-Axis During Horizontal Swipe
- Split the weekly view into:
  - fixed left hour axis (`_FixedHourAxis`),
  - horizontally paged schedule surface (`ScheduleWidget` with `showTimeLabels: false`).
- The hour axis no longer travels with horizontal drag.
- Added viewport interpolation (`TweenAnimationBuilder<_HourViewport>`) so start/end displayed hours animate smoothly after week settle.

### 3. High-Refresh Jank Reduction
- Removed `setState` calls in prefetch completion paths in `WeeklySchedulePage`; prefetch now warms cache without forcing extra immediate rebuilds.
- Changed `PerformanceTelemetry` frame logs to jank-only and throttled (500ms minimum interval).
- Gated verbose `ScheduleProvider` logs behind `kDebugMode` to reduce runtime logging pressure.

## Files Changed
- `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart`
- `lib/schedule/ui/weeklyschedule/widgets/schedule_widget.dart`
- `lib/common/logging/performance_telemetry.dart`
- `lib/schedule/business/schedule_provider.dart`
- `test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart`

## Why This Works
- `PageView` provides hardware-accelerated, direct-manipulation paging semantics expected on Android.
- Keeping the hour axis fixed removes unnecessary lateral visual motion and improves spatial stability.
- Deferred/non-blocking prefetch plus reduced logging lowers main-isolate churn, which is especially important at 90/120Hz where frame budgets are tighter.

## Validation
- `flutter test test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart -r compact` passed.
- Verified that:
  - drag progress updates before release,
  - week commit works through swipe and chevrons,
  - axis stays fixed while week content moves,
  - hour viewport adjusts with a short smooth animation after week settle.

## Prevention Strategies
- Avoid coupling static guides/axes with horizontally paged content unless motion is intentional.
- Treat prefetch as cache warmup only; do not force UI rebuild on completion without user-visible data dependency.
- Keep performance telemetry and provider logs throttled and scoped in interactive paths.
- Keep a device matrix for perf checks (high-refresh phone + tablet) before merging swipe/animation changes.

## Cross-References
- `docs/solutions/performance/weekly-swipe-interactive-pageview-20260211.md`
- `docs/solutions/performance/pixel8pro-weekly-scroll-jank-20260211.md`
