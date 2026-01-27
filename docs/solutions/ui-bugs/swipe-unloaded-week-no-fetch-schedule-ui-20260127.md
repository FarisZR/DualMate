---
module: Schedule UI
date: 2026-01-27
problem_type: ui_bug
component: frontend_stimulus
symptoms:
  - "Swipe to an unloaded week shows brief animation, then no week change"
  - "Logs show: 'Schedule fresh; skip network fetch' after swiping"
root_cause: logic_error
resolution_type: code_fix
severity: medium
tags: [swipe, schedule, week, fetch, freshness-gate, flutter]
---

# Troubleshooting: Swipe to unloaded week does not fetch

## Problem
After making weekly swipes more responsive, swiping into weeks that were not loaded stopped triggering a network fetch. The swipe animation flashed and then reverted without updating the schedule.

## Environment
- Module: Schedule UI
- Rails Version: N/A (Flutter)
- Affected Component: Weekly schedule swipe handling
- Date: 2026-01-27

## Symptoms
- Swipe to an unloaded week shows brief animation, then no week change.
- Logs show: `Schedule fresh; skip network fetch` after swiping.

## What Didn't Work

**Attempted Solution 1:** Reduce the request throttling to allow rapid swipes.
- **Why it failed:** The freshness check was global, so new date ranges were treated as fresh and skipped fetches.

## Solution

Make schedule freshness range-aware so new week ranges are always considered stale, while still skipping network fetches for recently fetched *same* ranges.

**Code changes**:
```dart
// Before (global freshness in weekly_schedule_view_model.dart):
// final isStale = _lastUpdatedAt == null
//     ? true
//     : now.difference(_lastUpdatedAt!).abs() > _staleAfter;

// After (range-aware freshness):
final ScheduleFreshnessGate _freshnessGate = ScheduleFreshnessGate();

final isStale = _freshnessGate.isStale(start, end, now);
if (isStale) {
  updatedSchedule = await _readScheduleFromService(
    start,
    end,
    cancellationToken,
  );
  _freshnessGate.markFetched(start, end, DateTime.now());
}
```

**New helper** (range-aware freshness gate):
```dart
class ScheduleFreshnessGate {
  final Duration staleAfter;
  DateTime? _lastFetchedAt;
  DateTime? _lastStart;
  DateTime? _lastEnd;

  ScheduleFreshnessGate({this.staleAfter = const Duration(minutes: 30)});

  bool isStale(DateTime start, DateTime end, DateTime now) {
    if (_lastFetchedAt == null || _lastStart == null || _lastEnd == null) {
      return true;
    }
    if (_lastStart != start || _lastEnd != end) {
      return true;
    }
    return now.difference(_lastFetchedAt!).abs() > staleAfter;
  }

  void markFetched(DateTime start, DateTime end, DateTime now) {
    _lastStart = start;
    _lastEnd = end;
    _lastFetchedAt = now;
  }
}
```

**Commands run**:
```bash
flutter test
flutter run -d 59RYD25806200107
```

## Why This Works
The original freshness check was global, so once any range was fetched, subsequent swipes to *different* ranges were treated as fresh and skipped fetching. By tracking freshness per range, new weeks are always stale and trigger a fetch, while repeat swipes to the same week within the freshness window still skip network calls.

## Prevention
- When caching data keyed by date ranges, track freshness per range, not globally.
- Add unit tests for gating logic to cover both same-range and different-range cases.
- Watch logs for `Schedule fresh; skip network fetch` when testing new ranges.

## Related Issues
No related issues documented yet.
