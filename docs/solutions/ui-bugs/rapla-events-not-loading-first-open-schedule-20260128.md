---
module: Schedule & Date Management
date: 2026-01-28
problem_type: ui_bug
component: service_object
symptoms:
  - "Schedule shows empty on first open and logs 'Schedule fresh; skip network fetch' with 0 cached entries"
  - "Rapla events page shows empty state or only first 3 months until user scrolls"
root_cause: logic_error
resolution_type: code_fix
severity: medium
tags: [rapla, lazy-loading, cache, schedule, freshness-gate, first-open]
---

# Troubleshooting: Rapla events and schedule empty on first open

## Problem
On first launch with an empty cache, the schedule page marked the range as fresh
and skipped the network fetch, leaving the list empty. The Rapla events page
also failed to load beyond the first window unless the user scrolled, showing an
empty-state message while data was still loading.

## Environment
- Module: Schedule & Date Management
- Affected Component: schedule cache/refresh + Rapla events paging
- Date: 2026-01-28

## Symptoms
- Schedule logs "Schedule fresh; skip network fetch" despite zero cached entries.
- Events page shows "no events" while initial fetch is in progress.
- Events list only loads the first 3-month window unless the user scrolls.

## What Didn't Work

**Attempted behavior:** rely on existing freshness gates and lazy-load triggers.
- **Why it failed:** freshness gates treated empty caches as fresh; lazy-load was
  only triggered by scroll position, which never changed on first open.

## Solution

1. Force a schedule fetch when cached entries are empty and the source can query.
2. Prefetch additional Rapla pages on first open to fill the screen.
3. Hide the Rapla empty-state message until loading finishes.
4. Add paging cooldown + "no more events" state to prevent infinite refresh.
5. Clamp Rapla paging to the next 3 years and stop at last non-holiday + 365 days.

**Code changes** (Dart):
```dart
// lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart
final shouldForceFetch = cachedSchedule.entries.isEmpty &&
    scheduleSourceProvider.currentScheduleSource.canQuery();
final isStale = shouldForceFetch ||
    _freshnessGate.isStale(start, end, now) ||
    _isWindowStale(start, end, now);
```

```dart
// lib/date_management/ui/viewmodels/date_management_view_model.dart
Future<void> _prefetchRaplaUntilFilled() async {
  for (var i = 0; i < 3; i++) {
    if (!_hasMoreRaplaPages) return;
    if (importantEventSections.isNotEmpty) return;
    await loadNextRaplaPage();
  }
}
```

```dart
// lib/date_management/ui/date_management_page.dart
if (!model.isLoading && !model.isLoadingNextRaplaPage)
  Center(child: Text(L.of(context).dateManagementRaplaEmpty))
```

**Commands run:**
```bash
flutter test
flutter run -d <DEVICE_ID>
```

## Why This Works
- Empty-cache schedules now bypass the freshness gate and fetch from Rapla.
- Rapla pages can load without user scroll, so the first view is populated.
- The empty-state message is only shown after loading completes.
- Cooldowns and cutoffs prevent repeated scraping and runaway pagination.

## Prevention
- Treat empty caches as stale for critical entry lists.
- Trigger pagination when content does not fill the viewport.
- Keep explicit paging caps (time-based and "no new events" stop rules).
- Verify initial open behavior on a cold cache during QA.

## Related Issues
- See also: [swipe-unloaded-week-no-fetch-schedule-ui-20260127.md](../ui-bugs/swipe-unloaded-week-no-fetch-schedule-ui-20260127.md)
