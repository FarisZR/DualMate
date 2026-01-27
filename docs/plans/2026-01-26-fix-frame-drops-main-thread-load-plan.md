---
title: fix: Reduce frame drops and main-thread load
type: fix
date: 2026-01-26
---

# Fix: Reduce frame drops and main-thread load

## Overview
Flutter profile logs show “Skipped 56 frames” indicating main-thread overload. Goal: instrument and reduce main-thread work so launch, tab switches, and data refreshes stay smooth on Android (Material 3).

## Scope / Out of Scope
- In scope: startup path (defer/allow first frame), root navigation tabs, schedule and canteen fetching/parsing, background updates (workmanager), Android widget DB reads, performance telemetry hooks, dev-only toggles.
- Out of scope: iOS-specific paths, new features unrelated to performance, design system changes beyond perf toggles, database schema changes.

## Problem Statement / Motivation
- First frame may be blocked by startup work before `allowFirstFrame`.
- Tab switches trigger synchronous data work/rebuilds causing jank.
- Schedule/canteen parsing might fall back to main thread; background tasks may surface errors.
- `notifyListeners` after dispose and constructor-time notifications can cause layout churn/warnings.

## Proposed Solution (high level)
- Define first-frame contract: only minimal UI prerequisites before `allowFirstFrame`; defer the rest post-first-frame.
- Instrument frame performance (FrameTiming listener, timeline events, TTFF logging) and add a dev toggle for the performance overlay.
- Ensure heavy parsing/fetching runs off the main thread (isolate) with safe fallback and cache-first + staleness thresholds.
- Tame `addPostFrameCallback` usage (run-once guards), defer constructor notifications, and add disposed/timer cancellation guards across viewmodels.
- Optimize list rendering (item extents, caching extent, const widgets, image placeholders/caching) for schedule/canteen views.
- Harden background tasks with try/catch, backoff, and rolling 7-day windows; keep widget DB access read-only.

## Detailed Plan & Tasks

### Instrumentation and guardrails
- Add a lightweight perf logger utility (timestamped spans + FrameTiming aggregation) usable from `main.dart` and key viewmodels; log TTFF, tab switches, and fetch/parse spans.
- Add dev-only toggle (e.g., via debug drawer/hidden tap in settings) for `showPerformanceOverlay` + verbose perf logs; ensure default off in release/profile.
- Wrap tab switches and first build with `Timeline.startSync`/`finishSync` markers for profile builds; document commands (`flutter run --profile -d <device>` and log filters).
- Add run-once guards around `addPostFrameCallback` usage in entry screens to prevent stacking.

### Startup path tightening
- In `lib/main.dart`: measure from process start to defer/allow; move non-essential init (e.g., analytics, optional warmups) behind first frame via `addPostFrameCallback`/microtask.
- In `lib/ui/root_page.dart`: allow first frame immediately after minimal shell ready; defer heavy DI resolution or data fetch to post-frame; add build/raster timing logs for first frame.
- Ensure initial navigation stack uses cached data when available; keep placeholders lightweight.

### Schedule and canteen threading
- Audit schedule and canteen fetch/parse flows to ensure isolate usage (`compute`/custom isolates); extract shared isolate helper if missing.
- Add isolate failure fallback: if spawn fails or parse throws, surface last-good cached data with freshness stamp; keep UI responsive and log error.
- Enforce cache-first with staleness threshold (15–30 min) on tab enter; trigger background refresh without blocking UI thread.

### ViewModel hygiene and notifications
- Add disposed guards to viewmodels used in schedule/canteen/root navigation; cancel timers/streams in `dispose` and gate `notifyListeners` after dispose.
- Remove constructor-time notifications; shift initial load triggers to `init`/post-frame guarded calls.
- Add a small helper for safe notify (`notifyIfMounted(propertyName)`) to centralize guard logic.

### List/UI rendering optimizations
- For schedule/canteen lists: set fixed `itemExtent` or `prototypeItem` where feasible; avoid `shrinkWrap` on long lists; tune `cacheExtent` to 2–3 screens.
- Use const constructors, lightweight placeholders for images/icons, and keyed list items to reduce rebuild churn.
- Verify images/icons cache policy; avoid synchronous decoding on main thread when possible.

### Background tasks and widgets
- Wrap background fetch/parse in try/catch with logging + retry/backoff; ensure failures do not crash workmanager.
- Constrain widget DB access to `OPEN_READONLY`; enforce rolling 7-day window for stored entries.
- Add minimal health metrics: count failures/successes and last-run timestamps in logs (non-PII).

### Documentation and reproducibility
- Update `docs/support/launch-and-orientation.md` (or new note) with commands to measure TTFF/frame timings, how to enable perf overlay, and where logs emit.
- Note cache/staleness policy and isolate fallback behavior in README/perf section.

## Milestones
- M1: Instrumentation in place (TTFF/frame logs, perf toggle), startup path tightened, documentation of measurement commands.
- M2: Schedule/canteen flows fully off-main-thread with isolate fallback and cache-first staleness; post-dispose guards applied; list optimizations.
- M3: Background tasks hardened (retry/backoff, read-only DB), rolling window enforced, perf overlay dev toggle verified on device.

## Technical Considerations
- **Startup/architecture**: `lib/main.dart` uses `deferFirstFrame`; `lib/ui/root_page.dart` calls `allowFirstFrame`. Move non-critical init after first frame; add timing logs around defer/allow and init blocks.
- **Threading**: Keep parsing on isolates (`lib/canteen/service/canteen_scraper.dart` pattern); add isolate-failure fallback that preserves last-good cache without blocking UI.
- **State management**: Apply disposed guards and cancel timers/streams; avoid `notifyListeners` in constructors; prefer post-frame deferred initial loads.
- **Navigation**: On tab switch, use cache-first with staleness (e.g., 15–30 min) and refresh in background; avoid blocking tab switches on network.
- **Lists/UI**: Use item extents where possible, avoid shrinkWrap on long lists, tune cacheExtent, use placeholders for images/icons, prefer const widgets/keys.
- **Background tasks**: Wrap schedule/canteen background updates in try/catch with logging; keep 7-day rolling windows; ensure Android widget DB access is `OPEN_READONLY`.
- **Tooling**: Provide a dev-only toggle for `showPerformanceOverlay`; add FrameTiming listener that logs avg build/raster and jank % around launch and tab switches; emit custom timeline events for init, fetch, parse, tab switch.

## Acceptance Criteria
- [ ] TTFF (cold start, profile/release, mid-tier Android) ≤ 1.5s from process start to first frame rendered.
- [ ] Jank rate < 1% and no “Skipped >16 frames” warnings during launch and tab switches (profile run).
- [ ] Tab switch perceived latency ≤ 150ms with cached data; background refresh does not block UI thread.
- [ ] Schedule and canteen parsing always off main thread; on isolate failure, UI stays responsive and shows last-good data.
- [ ] Zero occurrences of `notifyListeners`/`setState` after dispose in logs; timers/streams cancelled on dispose.
- [x] Background tasks log errors without crashing; retry/backoff applied; widgets read DB in read-only mode.
- [x] Perf instrumentation documented with commands to reproduce measurements.

## Success Metrics
- Median TTFF and 95th percentile for launch.
- Jank percentage and average frame build/raster times during tab switches and data refresh.
- Background task failure rate (target: <1% with graceful fallback).
- Zero post-dispose notifications in session logs.

## Dependencies & Risks
- Large schedule payloads or slow network could still stress parsing; ensure isolate fallback and cache-first policy.
- Excessive addPostFrame callbacks could still stack; must gate to run-once.
- If isolate spawn fails on some devices, need safe degradation path.
- Measuring in debug can be misleading; rely on profile/release for perf numbers.

## References & Research
- Startup frame control: `lib/main.dart`, `lib/ui/root_page.dart`.
- Isolate parsing pattern: `lib/canteen/service/canteen_scraper.dart`.
- Disposal/timer guards: `docs/solutions/runtime-errors/notifylisteners-after-dispose-schedule-20260126.md`.
- Background task hardening & rolling 7-day window: `docs/solutions/integration-issues/unhandled-background-exception-widget-logic-Schedule-20260124.md`.
- Defer notifications, read-only DB for widgets: `docs/solutions/integration-issues/canteen-widget-crashes-and-locking-Canteen-20260124.md`.
- Startup/launch guidance: `docs/support/launch-and-orientation.md`, `docs/plans/2026-01-22-fix-splash-orientation-landscape-plan.md`.
