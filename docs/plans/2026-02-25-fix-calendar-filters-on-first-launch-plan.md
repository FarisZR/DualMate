---
title: fix: load calendar filters on first launch
type: fix
date: 2026-02-25
issue: 31
---

# fix: load calendar filters on first launch

## 🐛 Overview

On fresh installs, the schedule filter list can render empty on first launch even though schedule data is fetched shortly after. This plan makes first-launch filter hydration deterministic so users can see class filters without killing and reopening the app.

## Problem Statement / Motivation

- Reported in `#31`: filter list is empty right after installation, then appears after app restart.
- This creates a broken-first-impression bug in a core schedule workflow.
- Current warmup timing uses fixed delays and can run before schedule source setup and first data persistence complete.
- An empty preloaded filter snapshot can remain cached for the whole process.

## Consolidated Research

### Internal architecture and code paths

- Static filter cache exists in `FilterViewModel` (`lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart:27`) and preload writes into it (`lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart:45`).
- Filter options come from DB distinct titles (`lib/schedule/data/schedule_entry_repository.dart:73`), so first-launch DB timing directly affects list population.
- Schedule page prewarms filters after `250ms` (`lib/schedule/ui/schedule_page.dart:169`) while schedule source setup is delayed by `1s` (`lib/schedule/ui/viewmodels/schedule_view_model.dart:36`).
- Weekly initial refresh exits early if source is not setup (`lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:160`), increasing race likelihood on first open.
- Schedule persistence currently does delete-then-save for the queried range (`lib/schedule/business/schedule_provider.dart:109`).

### Institutional learnings applied

- First-open cache behavior must treat not-yet-loaded data differently from true empty states (`docs/solutions/ui-bugs/rapla-events-not-loading-first-open-schedule-20260128.md:41`).
- Async schedule initialization should use explicit readiness states, not optimistic UI assumptions (`docs/solutions/ui-bugs/schedule-setup-prompt-during-init-20260202.md:37`).
- Filter-triggered schedule refreshes need deterministic invalidation/force-refresh behavior (`docs/solutions/ui-bugs/filters-dont-apply-calendar-without-interaction-20260209.md:34`).

### Research decision

This is a repo-local schedule initialization bug with strong existing patterns and related prior fixes, so external research is skipped for this planning pass.

## ✨ Proposed Solution

Implement readiness-driven filter hydration and remove dependence on fragile startup timers.

1. Gate filter prewarm on schedule readiness milestones rather than a fixed delay.
2. Treat first empty preload as provisional until source setup + first fetch attempt complete.
3. Invalidate/reload filter state when schedule data transitions from empty to populated in the same process.
4. Keep warm-start performance optimizations for returning users (fast cached filter open).
5. Add race-focused tests for first-launch timing permutations.

## Technical Considerations

- **Correctness over timing hacks:** use explicit readiness signals/events; avoid relying on `250ms`/`1s` ordering.
- **State semantics:** differentiate `loading`, `ready`, `empty-final`, and `error` for filter UI.
- **Cache scope:** static filter cache should not persist provisional empty results as authoritative.
- **Regression safety:** preserve existing behavior where filter apply triggers immediate weekly refresh.
- **Android priority:** validate on real Android device lifecycle, aligned with project constraints.

## SpecFlow Gaps + Defaults

- **Gap:** What should gate first filter prewarm?  
  **Default:** only preload after schedule source setup has completed and first schedule fetch has been attempted.
- **Gap:** Is an empty preload result final?  
  **Default:** no; empty is provisional until readiness criteria are met.
- **Gap:** Which events invalidate filter cache?  
  **Default:** invalidate on schedule source change, successful first schedule refresh, and detected title-count transition from `0 -> >0`.
- **Gap:** What should users see while filters are not ready?  
  **Default:** explicit loading state (not blank list), with retry only on terminal load error.
- **Gap:** How should offline first-launch behave?  
  **Default:** show recoverable error/offline state and auto-reload when connectivity/data arrives.

## ✅ Acceptance Criteria

- [ ] On fresh install first launch, class filters appear without requiring app restart when schedule entries exist.
- [ ] Filter UI shows loading while class names are hydrating; it does not silently render an empty list for in-progress initialization.
- [ ] Empty filter state is shown only when initialization is complete and there are truly no filterable classes.
- [ ] After first successful schedule refresh in-process, filter cache refreshes automatically if previously empty.
- [ ] Existing filter apply behavior still triggers immediate schedule refresh in the visible week.
- [ ] Behavior is deterministic across timing permutations (open schedule very early vs after setup).
- [ ] Automated regression tests for issue `#31` are added and pass.

## Success Metrics

- Repro steps from `#31` are no longer reproducible on a fresh install.
- No restart-required filter population in Android manual QA runs.
- New tests fail on old behavior and pass with fix.

## Dependencies & Risks

- **Risk:** over-gating could delay filter availability on warm starts.  
  **Mitigation:** keep fast-path for already-ready state and verify startup performance.
- **Risk:** cache invalidation could trigger redundant reloads.  
  **Mitigation:** reload only on explicit state transitions (`0 -> >0`, source changed, first refresh complete).
- **Risk:** readiness plumbing may overlap with schedule setup placeholder logic.  
  **Mitigation:** align with existing initialization contract in `ScheduleViewModel`.

## MVP Flow Sketch

```dart
// lib/schedule/ui/schedule_page.dart (pseudo)
if (scheduleViewModel.didAttemptSetup && !scheduleViewModel.isInitializingScheduleSource) {
  await FilterViewModel.preloadStates(entryRepo, filterRepo);
}
```

```dart
// lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart (pseudo)
if (loadedNames.isEmpty && !firstLaunchHydrationSettled) {
  showLoadingState();
} else {
  publishFilterStates(loadedNames);
}
```

## 📋 Implementation Checklist (draft)

- [ ] Define first-launch filter readiness contract in `lib/schedule/ui/schedule_page.dart` and `lib/schedule/ui/viewmodels/schedule_view_model.dart`.
- [x] Update filter preload/cache semantics in `lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart` to avoid sticky provisional empties.
- [ ] Ensure filter refresh/invalidation is triggered when schedule data becomes available in-process via `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart` and/or `lib/schedule/business/schedule_provider.dart` callbacks.
- [ ] Add explicit non-ready/loading handling in `lib/schedule/ui/weeklyschedule/filter/schedule_filter_page.dart`.
- [x] Add regression tests for first-launch timing race under `test/schedule/ui/viewmodels/filter_view_model_cache_test.dart`.
- [x] Add/extend viewmodel tests for preload/invalidation behavior under `test/schedule/ui/viewmodels/filter_view_model_cache_test.dart`.
- [ ] Record final fix in `docs/solutions/ui-bugs/` after implementation.

## Test Plan

### Automated

- Add test: prewarm before source setup does not persist empty final filter list (`test/schedule/ui/viewmodels/filter_view_model_cache_test.dart`).
- Add test: first successful schedule refresh repopulates filter states in same process (`test/schedule/ui/viewmodels/filter_view_model_cache_test.dart`).
- Add widget test: filter page shows loading then populated list on first launch path (`test/schedule/ui/weeklyschedule/schedule_filter_first_launch_test.dart`).
- Re-run related existing suites:
  - `test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`
  - `test/schedule/ui/viewmodels/schedule_update_request_gate_test.dart`

### Manual Android verification

- Install clean build, configure schedule source, open schedule quickly, then open filters; verify list populates without restart.
- Repeat with delayed open (>2s after launch) to validate no warm-start regression.
- Test offline/slow network first-launch behavior; verify loading/error state is explicit and recoverable.
- Background app and resume; ensure filters remain populated and consistent.

## AI-Era Implementation Notes

- Keep implementation narrow to issue `#31`; avoid unrelated schedule/filter redesign.
- Follow TDD: write failing first-launch regression tests before behavior changes.
- Require human review for cache lifecycle changes, since race-condition fixes are easy to overfit.

## References & Research

### Related issues

- `#31`
- `#20`

### Internal references

- `lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart:27`
- `lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart:45`
- `lib/schedule/ui/schedule_page.dart:169`
- `lib/schedule/ui/viewmodels/schedule_view_model.dart:36`
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:160`
- `lib/schedule/data/schedule_entry_repository.dart:73`
- `lib/schedule/business/schedule_provider.dart:109`
- `test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart:75`

### Institutional learnings

- `docs/solutions/ui-bugs/filters-dont-apply-calendar-without-interaction-20260209.md:34`
- `docs/solutions/ui-bugs/rapla-events-not-loading-first-open-schedule-20260128.md:41`
- `docs/solutions/ui-bugs/schedule-setup-prompt-during-init-20260202.md:37`
- `docs/rapla-cache-refresh-behavior.md:49`
