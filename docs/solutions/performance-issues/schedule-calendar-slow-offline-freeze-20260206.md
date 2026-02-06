---
module: Schedule & Date Management
date: 2026-02-06
problem_type: performance_issue
component: service_object
symptoms:
  - "Schedule calendar block loads slowly after performance changes"
  - "Offline mode shows no connection banner inconsistently"
  - "Schedule week navigation freezes when offline"
root_cause: async_timing
resolution_type: code_fix
severity: high
tags: [schedule, offline, cache, warmup, performance]
---

# Troubleshooting: Schedule calendar slow load and offline freeze

## Problem
After performance optimizations, the schedule calendar block became slow to render on startup and offline handling regressed. The no-connection banner either did not appear or blocked week navigation when the connection dropped.

## Environment
- Module: Schedule & Date Management
- Affected Component: schedule viewmodels + schedule cache
- Date: 2026-02-06

## Symptoms
- Calendar block appears noticeably later on schedule page open.
- No-connection banner does not show when offline on launch.
- When connectivity drops, the banner appears but week navigation gets stuck (cannot swipe back).

## What Didn't Work

**Attempted Solution 1:** Deferring schedule setup/refresh with shell-first delays.
- **Why it failed:** It delayed the first cached render and introduced new timing windows where the banner state never updated.

**Attempted Solution 2:** Gating refresh on schedule setup only.
- **Why it failed:** Offline refresh failures prevented week changes from updating the cached view, freezing navigation.

## Solution

1. Prewarm schedule cache during deferred initialization so the first schedule render can read cached data without blocking.
2. Render cached schedule even while setup is still initializing; only show the “no connection” banner after a real setup attempt fails.
3. Always load cached week data before network refresh when navigating weeks, so offline navigation stays responsive.

**Code changes** (Dart):
```dart
// lib/schedule/business/schedule_provider.dart
Schedule? _cachedSchedule;
DateTime? _cachedScheduleStart;
DateTime? _cachedScheduleEnd;

Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async {
  if (_cachedSchedule != null &&
      _cachedScheduleStart != null &&
      _cachedScheduleEnd != null &&
      _cachedScheduleStart == start &&
      _cachedScheduleEnd == end) {
    return _cachedSchedule!;
  }

  var cachedSchedule =
      await _scheduleEntryRepository.queryScheduleBetweenDates(start, end);
  cachedSchedule = await _scheduleFilter.filter(cachedSchedule);

  _cachedSchedule = cachedSchedule;
  _cachedScheduleStart = start;
  _cachedScheduleEnd = end;
  return cachedSchedule;
}

Future<void> warmScheduleCache(DateTime start, DateTime end) async {
  await getCachedSchedule(start, end);
}
```

```dart
// lib/ui/root_page.dart
Future<void> _prewarmScheduleCache() async {
  final scheduleProvider = KiwiContainer().resolve<ScheduleProvider>();
  final start =
      toStartOfDay(toDayOfWeek(DateTime.now(), DateTime.monday));
  final end = toNextWeek(start);
  await scheduleProvider.warmScheduleCache(start, end);
}
```

```dart
// lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart
Future<void> _openWeekFromCache(DateTime start, DateTime end) async {
  final cachedSchedule =
      await scheduleProvider.getCachedSchedule(start, end);
  if (_isDisposed) return;
  _setSchedule(cachedSchedule, start, end);
}

Future nextWeek() async {
  final nextStart = toNextWeek(currentDateStart);
  final nextEnd = toNextWeek(currentDateEnd);
  await _openWeekFromCache(nextStart, nextEnd);
  await updateSchedule(nextStart, nextEnd);
}
```

```dart
// lib/schedule/ui/schedule_page.dart
if (!viewModel.didSetupProperly && !hasCachedSchedule) {
  if (viewModel.isInitializingScheduleSource ||
      !viewModel.didAttemptSetup) {
    return ScheduleEmptyStatePlaceholder();
  }
  return ScheduleEmptyState();
}

if (!viewModel.didSetupProperly &&
    viewModel.didAttemptSetup &&
    !viewModel.isInitializingScheduleSource) {
  return Column(
    children: [
      BannerWidget(...),
      Expanded(child: pager),
    ],
  );
}
```

**Commands run:**
```bash
flutter test
flutter run --profile -d <DEVICE_ID>
```

## Why This Works
- Cache prewarming ensures the first schedule render does not wait on DB reads.
- Rendering cached data even during setup prevents the “no connection” state from blocking the calendar.
- Week navigation loads from cache first, so offline transitions remain responsive while refreshes fail safely in the background.

## Prevention
- Prewarm critical cached data before first open of heavy screens.
- Always show cached content while setup or refresh is in progress.
- Allow navigation to update the view from cached data even when network refresh fails.

## Related Issues
- See also: [rapla-events-not-loading-first-open-schedule-20260128.md](../ui-bugs/rapla-events-not-loading-first-open-schedule-20260128.md)
