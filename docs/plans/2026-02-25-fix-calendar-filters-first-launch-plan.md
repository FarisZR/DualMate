---
title: fix: load calendar filters correctly on first launch
type: fix
date: 2026-02-25
issue: 31
---

# fix: load calendar filters correctly on first launch

## 🐛 Overview

On a fresh install, the schedule filter list can open as empty even though classes are fetched shortly after. Users currently need to close and relaunch the app before filters appear. This plan removes first-launch race conditions and ensures filter state resolves in-session without restart.

## Problem Statement / Motivation

- Reported in `#31`: class filters are empty on first launch and appear only after app restart.
- This creates a misleading UX: users interpret an initialization race as "no classes".
- Current startup timing prewarms filter state before schedule source setup and first schedule fetch complete.
- Filter state is statically cached; if the first read is empty, that empty state can persist for the whole process.

## Consolidated Research

### Internal architecture and code paths

- `SchedulePage` triggers schedule init, weekly init, and filter prewarm during first frame:
  - `lib/schedule/ui/schedule_page.dart:65`
  - `lib/schedule/ui/schedule_page.dart:69`
  - `lib/schedule/ui/schedule_page.dart:70`
  - `lib/schedule/ui/schedule_page.dart:71`
- Filter prewarm uses a fixed 250ms delay (not data readiness):
  - `lib/schedule/ui/schedule_page.dart:169`
  - `lib/schedule/ui/schedule_page.dart:171`
- Schedule source setup starts on a delayed 1s timer:
  - `lib/schedule/ui/viewmodels/schedule_view_model.dart:34`
  - `lib/schedule/ui/viewmodels/schedule_view_model.dart:36`
  - `lib/schedule/ui/viewmodels/schedule_view_model.dart:41`
- Filter state cache is static and shared in-process:
  - `lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart:27`
  - `lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart:45`
  - `lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart:72`
- Filter options are derived from `ScheduleEntries` titles:
  - `lib/schedule/data/schedule_entry_repository.dart:73`
- Related behavior context from previous filter bugfix:
  - Issue `#20`
  - PR `#21`

### Institutional learnings applied

- Treat empty cache as stale for first-open critical paths; do not accept empty as final before initialization completes:
  - `docs/solutions/ui-bugs/rapla-events-not-loading-first-open-schedule-20260128.md:41`
  - `docs/solutions/ui-bugs/rapla-events-not-loading-first-open-schedule-20260128.md:87`
- Async initialization should show neutral/loading state instead of misleading empty/setup state:
  - `docs/solutions/ui-bugs/schedule-setup-prompt-during-init-20260202.md:37`
  - `docs/solutions/ui-bugs/schedule-setup-prompt-during-init-20260202.md:85`
- Filter flows may require explicit forced refresh/invalidation behavior to avoid stale UI:
  - `docs/solutions/ui-bugs/filters-dont-apply-calendar-without-interaction-20260209.md:34`

### Research decision

Local repo context and institutional learnings are strong for this bug class, so external best-practice/framework research is skipped.

## ✨ Proposed Solution

Introduce readiness-aware filter loading so early empty reads are treated as provisional, not final.

High-level approach:

1. Add explicit filter-loading readiness semantics (initializing vs ready-empty vs ready-populated).
2. Prevent static empty-cache poisoning during first-launch initialization.
3. Add recovery path when cached filter state is empty but schedule data becomes available later in the same session.
4. Preserve current cache-first behavior and performance optimizations for warm paths.

### MVP pseudo-flow

File: `lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart`

```dart
// Pseudocode only
if (cachedStates.isNotEmpty) return cachedStates;

if (scheduleInitializationPending) {
  emitLoadingState();
  await waitForScheduleReadyOrTimeout();
}

final loaded = await loadStatesFromRepositories();
cacheLoadedStatesOnlyWhenSemanticallyFinal(loaded, readiness);
return loaded;
```

## Technical Considerations

- **Startup ordering:** keep deferred startup work (performance) while avoiding first-read false empties.
- **Cache semantics:** cache should differentiate transient empty from true empty.
- **Source setup state:** filter UI must not imply "no classes" while source setup/fetch is still pending.
- **Regression safety:** do not break filter-apply refresh behavior fixed in `#20/#21`.
- **Platform scope:** Flutter/Android path only, aligned with project constraints.

## SpecFlow Gaps + Defaults

- **Gap:** Should an empty preload result be cached before schedule initialization completes?  
  **Default:** No. Treat as provisional and retry after readiness.
- **Gap:** What should the filter page show if opened during initialization?  
  **Default:** Loading/skeleton state with retry-safe path.
- **Gap:** How to distinguish true empty vs not-yet-loaded?  
  **Default:** Use an explicit readiness signal; show empty only when ready=true and query result is empty.
- **Gap:** What if source is not configured?  
  **Default:** Show setup-required state (not empty class list) with clear action.
- **Gap:** Timeout behavior for long/failed initialization?  
  **Default:** After 8-10s, show recoverable error with retry.

## ✅ Acceptance Criteria

- [ ] Fresh install: opening filters during first seconds of app use does not show false-empty class list.
- [ ] Filter UI shows loading/setup-required state while initialization is incomplete, not a misleading empty list.
- [ ] Once schedule entries are available, filter list populates in the same app session without relaunch.
- [ ] Empty filter list appears only when initialization is complete and repository query confirms no class titles.
- [ ] Static filter cache does not permanently store transient first-launch empty results.
- [ ] Existing filter apply behavior still triggers immediate weekly refresh (no regression of `#20/#21`).
- [ ] New regression tests for issue `#31` pass in CI.

## Success Metrics

- Repro steps from `#31` are no longer reproducible across clean-install test runs.
- Manual Android first-launch validation shows filters appear without app restart.
- Added tests deterministically cover the initialization race and empty-cache recovery paths.

## Dependencies & Risks

- **Risk:** introducing readiness state can add UI complexity and edge cases.  
  **Mitigation:** keep state model minimal (`loading`, `ready`, `error`) and test transitions.
- **Risk:** extra reload logic may increase startup DB/network work.  
  **Mitigation:** use bounded retry/single-flight and preserve cache-first reads.
- **Risk:** cache invalidation changes could impact other schedule flows.  
  **Mitigation:** run related schedule viewmodel and weekly page tests.

## 📋 Implementation Checklist (draft)

- [ ] Add regression-first tests for first-launch filter race in `test/schedule/ui/weeklyschedule/filter/filter_view_model_first_launch_test.dart`.
- [ ] Add/adjust filter loading state handling in `lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart`.
- [ ] Ensure filter prewarm path in `lib/schedule/ui/schedule_page.dart` does not finalize transient empty cache.
- [ ] Add UI state handling in `lib/schedule/ui/weeklyschedule/filter/schedule_filter_page.dart` for loading/setup-required/error.
- [ ] Verify schedule source readiness interactions via `lib/schedule/ui/viewmodels/schedule_view_model.dart` and `lib/schedule/business/schedule_source_provider.dart`.
- [ ] Add regression guard for non-regression of filter apply refresh behavior in `test/schedule/ui/viewmodels/weekly_schedule_filter_refresh_regression_test.dart`.
- [ ] Record final implementation learnings in `docs/solutions/ui-bugs/`.

## Test Plan

### Automated

- Add unit tests for cache semantics and recovery behavior:
  - `test/schedule/ui/weeklyschedule/filter/filter_view_model_first_launch_test.dart`
  - `test/schedule/ui/weeklyschedule/filter/filter_view_model_cache_semantics_test.dart`
- Add widget test for opening filter page before schedule readiness:
  - `test/schedule/ui/weeklyschedule/filter/schedule_filter_page_initialization_state_test.dart`
- Add regression coverage for existing refresh behavior:
  - `test/schedule/ui/viewmodels/schedule_update_request_gate_test.dart`
  - `test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart`

### Manual Android verification

- Clear app data / fresh install.
- Configure schedule source and immediately open schedule filter UI.
- Confirm loading state transitions to populated class filters without restarting app.
- Repeat under slow/offline network conditions and verify recoverable behavior.
- Verify changing filters still updates weekly schedule immediately.

## AI-Era Implementation Notes

- Keep AI-assisted implementation tightly scoped to issue `#31` and startup/filter initialization paths.
- Use test-first workflow to prevent reintroducing first-open race conditions.
- Require human review of state-model transitions and empty-state semantics.

## References & Research

### Related issue and prior work

- `#31`
- `#20`
- `#21`
- https://github.com/FarisZR/DualMate/issues/31
- https://github.com/FarisZR/DualMate/issues/20
- https://github.com/FarisZR/DualMate/pull/21

### Internal code references

- `lib/schedule/ui/schedule_page.dart:65`
- `lib/schedule/ui/schedule_page.dart:169`
- `lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart:27`
- `lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart:45`
- `lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart:72`
- `lib/schedule/ui/viewmodels/schedule_view_model.dart:34`
- `lib/schedule/ui/viewmodels/schedule_view_model.dart:36`
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:154`
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:409`
- `lib/schedule/data/schedule_entry_repository.dart:73`

### Institutional learnings

- `docs/solutions/ui-bugs/rapla-events-not-loading-first-open-schedule-20260128.md:41`
- `docs/solutions/ui-bugs/schedule-setup-prompt-during-init-20260202.md:37`
- `docs/solutions/ui-bugs/filters-dont-apply-calendar-without-interaction-20260209.md:34`
- `docs/rapla-cache-refresh-behavior.md:49`
