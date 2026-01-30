---
title: fix: Rapla events lazy loading cache
type: fix
date: 2026-01-28
---

# fix: Rapla events lazy loading cache

🐛 The Rapla events page fetches a multi-year range and uses a custom JSON cache, making it feel slow and inconsistent with the main schedule. This plan switches the events page to the shared schedule cache and adds lazy loading so the first screen appears quickly.

## Overview

Align the Date Management (Rapla events) data path with the main schedule cache (ScheduleProvider + repositories) and introduce paged loading. The first page loads quickly from cache, then fetches additional future windows on scroll. This removes the multi-year fetch and makes perceived performance consistent with the schedule tab.

## Problem Statement / Motivation

- The Rapla events page requests a large date range and blocks on network/parsing, which appears broken to users.
- The page uses a separate Preferences JSON cache, so freshness differs from the schedule view.
- The UI builds a full list inside a non-lazy scroll container, increasing frame and memory cost.

## Proposed Solution

- Replace the custom Rapla events cache with the shared schedule cache.
- Page the Rapla events list by fixed 3-month windows.
- Switch the UI to a single lazy list with a load-more trigger near the end.

## Technical Considerations

- **Caching**: use ScheduleProvider / ScheduleEntryRepository for cache reads; rely on ScheduleQueryInformationRepository + ScheduleFreshnessGate for staleness checks.
- **Pagination**: default to 3-month windows; fetch the next future window when user scrolls near the end.
- **Filters**: hide the date selector; the Rapla events list is future-only.
- **Ordering & dedupe**: merge pages in chronological order; dedupe by title/type/start/end (same as existing RaplaImportantEventsProvider logic).
- **UI**: remove nested scrolls and render a single ListView.builder with a loading footer.

## Acceptance Criteria

- [x] Rapla events are derived from the schedule cache (ScheduleProvider-backed), not Preferences JSON.
- [x] Initial load fetches only the next 3 months and shows cached results immediately when present.
- [x] Events render incrementally as cache results and network updates arrive, without waiting for the full page to finish.
- [x] Additional pages load lazily on scroll; no multi-year fetch happens on first load.
- [x] Date selector is hidden on the Rapla events page; only future events are shown.
- [x] Events stay sorted chronologically and are deduped across pages.
- [x] The events list uses a single lazy list (no nested scroll) and remains smooth.
- [x] Error states are per-page and allow retry without losing prior pages.

## Success Metrics

- First contentful events list appears within 1 second on a warm cache.
- Network requests per session drop compared to full-range fetches.
- No reports of the events page appearing stuck on slow connections.

## Dependencies & Risks

- **Risk**: Wrong cache range could show missing events. Mitigation: align page windows to week boundaries and reuse ScheduleFreshnessGate range checks.
- **Risk**: Overlapping pages could duplicate events. Mitigation: reuse existing dedupe key.
- **Dependency**: ScheduleProvider and RaplaScheduleSource behavior, including isolate parsing and Rapla URL validation.

## Implementation Sketch

1. **Data layer**
   - Update `RaplaImportantEventsProvider` to read from the schedule cache (ScheduleProvider or ScheduleEntryRepository) for a given range.
   - If stale, request updates through ScheduleProvider, then re-read from cache.
   - Keep the existing `filterImportantEntries` and `mergeImportantEntries` logic.

2. **ViewModel paging**
   - Add pagination state to `DateManagementViewModel`:
     - current page window (start/end)
     - loaded events list
     - isLoadingNextPage / nextPageFailed
   - Replace `_readRaplaImportantEvents` with `_readRaplaImportantEventsPage`.
   - Set the initial window to now..now+3 months, and advance forward-only.

3. **UI lazy list**
   - Replace `SingleChildScrollView` + nested `ListView.separated` with a single `ListView.builder`.
   - Use a scroll controller to trigger `loadNextPage` when nearing the end.
   - Add a loading footer and retry action for page failures.

4. **Freshness / caching**
   - Reuse `ScheduleFreshnessGate` for Rapla events pages.
   - Use `ScheduleProvider.getCachedSchedule()` first, then fetch if stale.

## Example (pseudo)

### lib/date_management/ui/viewmodels/date_management_view_model.dart

```dart
Future<void> loadNextRaplaPage() async {
  if (_isLoadingNextPage || !_hasMorePages) return;
  _isLoadingNextPage = true;
  notifyListeners("isLoadingNextPage");

  final window = _nextPageWindow();
  final cached = await _scheduleProvider.getCachedSchedule(
    window.start,
    window.end,
  );
  _appendImportantEvents(_toImportantEvents(cached));

  if (_freshnessGate.isStale(window.start, window.end, DateTime.now())) {
    await _scheduleProvider.getUpdatedSchedule(
      window.start,
      window.end,
      _updateMutex.token,
    );
    final updated = await _scheduleProvider.getCachedSchedule(
      window.start,
      window.end,
    );
    _replaceEventsForWindow(window, _toImportantEvents(updated));
  }

  _isLoadingNextPage = false;
  notifyListeners("isLoadingNextPage");
}
```

## References & Research

### Internal References

- `lib/date_management/ui/viewmodels/date_management_view_model.dart`
- `lib/date_management/ui/date_management_page.dart`
- `lib/date_management/business/rapla_important_events_provider.dart`
- `lib/schedule/business/schedule_provider.dart`
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart`
- `lib/schedule/ui/viewmodels/schedule_freshness_gate.dart`
- `docs/solutions/ui-bugs/swipe-unloaded-week-no-fetch-schedule-ui-20260127.md`
- `docs/rapla_dates_integration.md`

### External Research

- Not required; strong local patterns exist for caching and range freshness.

## AI-Era Considerations

- Use rapid iteration to validate paging behavior on-device and ensure no UI jank.
- Prioritize regression tests and manual device validation due to the cross-module cache change.
- Record any AI-assisted changes in the PR description for human review.
