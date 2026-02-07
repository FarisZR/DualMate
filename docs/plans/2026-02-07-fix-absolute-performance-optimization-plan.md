---
---
title: fix: Absolute performance optimization (startup + schedule)
type: fix
date: 2026-02-07
---
# Fix: Absolute performance optimization (startup + schedule)
## Overview
Profile logs show severe jank during cold start and schedule loading:
- Skipped 124 frames at launch
- Skipped 44 frames during base init
- Skipped 56 frames during schedule loading
Timing hotspots: localizations 263ms, save language 326ms, prefs 328ms, background init 2413ms, canteen refresh 1667ms, calendar sync 1668ms. This plan focuses on eliminating main-thread stalls and reducing frame drops for startup and schedule flows.
## Problem Statement / Motivation
The app performs heavy initialization and data work on the UI thread, causing long frame stalls during first frame and schedule navigation. This hurts perceived performance and risks user drop-off.
## Proposed Solution
- Tighten the first-frame contract: only minimal prerequisites before `allowFirstFrame`; everything else deferred or offloaded.
- Enforce off-main-thread parsing and cache-first refreshes for schedule and canteen.
- Add concrete performance instrumentation using `PerformanceTelemetry` for TTFF, frame timing, and tab navigation.
- Guard viewmodel lifecycle and post-frame callbacks to avoid rebuild churn.
- Optimize list rendering for schedule/canteen views.
## Technical Considerations
- Startup/first frame: `lib/main.dart`, `lib/ui/root_page.dart` use `deferFirstFrame()` and `allowFirstFrame()`. Keep the shell light and allow first frame as early as possible.
- Performance telemetry exists in `lib/common/logging/performance_telemetry.dart`. Use it to log TTFF and frame timings around startup and schedule flows.
- Cache-first patterns and background updates already exist; align with `docs/rapla-cache-refresh-behavior.md`.
- Follow MVVM hygiene and disposal guards in `docs/solutions/runtime-errors/notifylisteners-after-dispose-schedule-20260126.md`.
## Detailed Plan
### 1) Instrumentation & Metrics
- [x] Wire `PerformanceTelemetry.ensureFrameTimingListenerAttached()` in startup for profile/debug.
- [x] Log TTFF timestamps around `deferFirstFrame()` and `allowFirstFrame()`.
- [x] Add timeline markers around:
  - `_initializeApp()` in `lib/ui/root_page.dart`
  - Schedule screen entry and refresh
  - Canteen refresh
- [x] Add a dev-only toggle for `showPerformanceOverlay` in `RootPage`.
### 2) Startup Path Tightening
- [x] Move non-critical work (background init, canteen refresh, calendar sync) strictly after the first frame and/or to background isolates.
- [x] Ensure localization + minimal preferences are the only blocking steps before first frame.
- [x] Add run-once guards around `addPostFrameCallback` to avoid stacking.
- [x] Defer heavy foreground init (canteen refresh + calendar sync) until after first render.
### 3) Schedule & Canteen Offloading
- [x] Audit schedule parsing and canteen scraping to ensure isolate usage.
- [x] Add safe fallback: if isolate fails, show cached data with “last updated” label, and log errors without blocking.
- [x] Enforce cache-first refresh with a staleness threshold (15–30 min) on schedule tab entry.
### 4) ViewModel Lifecycle Hygiene
- [x] Ensure no `notifyListeners` in constructors.
- [x] Add `notifyIfMounted` helper to prevent post-dispose updates.
- [x] Cancel timers/streams and guard async callbacks on dispose.
### 5) List Rendering Optimizations
- [x] For schedule and canteen lists:
  - Use `itemExtent` or `prototypeItem` where possible.
  - Avoid `shrinkWrap` on long lists.
  - Tune `cacheExtent` to ~2–3 screens.
  - Prefer const widgets and stable keys.
### 6) Background Tasks & Widgets
- [x] Harden workmanager tasks with try/catch + backoff.
- [x] Ensure widget DB reads are read-only and operate within rolling 7-day windows.
- [x] Emit minimal success/failure metrics for background sync.
## Acceptance Criteria
- [ ] Cold-start TTFF ≤ 1.5s on mid-tier Android in profile.
- [ ] No “Skipped >16 frames” warnings during launch or schedule tab switch (profile).
- [ ] Schedule tab shows cached data within 150ms; refresh runs in background.
- [ ] Parsing for schedule/canteen runs off main thread; fallback to cached data on isolate failure.
- [ ] Zero `notifyListeners`/`setState` after dispose in logs.
- [ ] Background tasks fail gracefully with retry/backoff and do not block UI.
## Success Metrics
- Median + p95 TTFF and TTI
- Jank % during startup and schedule navigation
- Average build/raster times during schedule interactions
- Background task failure rate <1%
## Dependencies & Risks
- Large schedule payloads may still be heavy; isolate fallback must be reliable.
- Debug logs can mislead; profile/release runs required.
- Over-deferring could delay data too long; balance with user expectations.
## References & Research
- Startup frame control: `lib/main.dart`, `lib/ui/root_page.dart`
- Perf telemetry: `lib/common/logging/performance_telemetry.dart`
- Existing performance plan: `docs/plans/2026-01-26-fix-frame-drops-main-thread-load-plan.md`
- Launch behavior: `docs/support/launch-and-orientation.md`
- Schedule cache policy: `docs/rapla-cache-refresh-behavior.md`
- ViewModel disposal guard: `docs/solutions/runtime-errors/notifylisteners-after-dispose-schedule-20260126.md`
