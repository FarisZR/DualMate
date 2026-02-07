---
module: Schedule
date: 2026-01-26
problem_type: runtime_error
component: background_job
symptoms:
  - "Flutter runtime warning: setState()/notifyListeners called after dispose when leaving schedule tab"
  - "PropertyChangeProvider/ChangeNotifier still firing after widget disposed"
root_cause: thread_violation
resolution_type: code_fix
severity: medium
tags: [flutter, notifylisteners, dispose, schedule, property-change-notifier]
---

# Troubleshooting: NotifyListeners after dispose in Schedule view models

## Problem
Entering then leaving the Schedule tab could log "setState()/notifyListeners called after dispose" because view models continued to notify after their widgets were disposed.

## Environment
- Module: Schedule
- Rails Version: N/A (Flutter)
- Affected Component: Schedule view models using PropertyChangeNotifier
- Date: 2026-01-26

## Symptoms
- Runtime warning: `setState() called after dispose` / `notifyListeners called after dispose` when navigating away from Schedule tab.
- Logs implicated `ScheduleViewModel` and `WeeklyScheduleViewModel` dispatching updates after teardown.

## What Didn't Work

**Attempted Solution 1:** Rely on default ChangeNotifier disposal without guards.
- **Why it failed:** Pending timers and async refreshes still fired after the widget tree removed listeners, causing late notifications.

### Solution (Modernized)

We have standardized on using `notifyIfMounted(String property)` in `BaseViewModel` instead of manual `if (!_isDisposed) notifyListeners(property)` checks. This helper centralizes the disposal guard.

```dart
// base_view_model.dart
void notifyIfMounted(String property) {
  if (isDisposed) return;
  notifyListeners(property);
}

// weekly_schedule_view_model.dart
Future updateSchedule(DateTime start, DateTime end) async {
  if (isDisposed) return;
  await _updateMutex.acquireAndCancelOther();
  if (isDisposed) { _updateMutex.release(); return; }
  try {
    isUpdating = true;
    notifyIfMounted("isUpdating");
    await _doUpdateSchedule(start, end);
  } finally {
    isUpdating = false;
    _updateMutex.release();
    notifyIfMounted("isUpdating");
  }
}
```

Key changes:
1. Inherit from `BaseViewModel` and use `notifyIfMounted`.
2. Ensure `isDisposed` is set and all callbacks/timers are removed in `dispose()`.
3. Use `cancellationToken.throwIfCancelled()` and re-check `isDisposed` after every async `await`.

## Why This Works

PropertyChangeNotifier/ChangeNotifier warns when listeners are invoked after the notifier is disposed. Pending timers and async refreshes were firing after disposal. By marking `_isDisposed`, canceling timers/mutex tokens, and skipping notifications when disposed, no callbacks fire into torn-down widgets.

## Prevention
- Always guard async callbacks and timers in view models with a disposed flag before notifying listeners.
- Cancel periodic timers and in-flight mutex/cancellation tokens in `dispose()`.
- For long-running async refreshes, re-check `mounted/_isDisposed` after awaits before notifying.

## Related Issues
No related issues documented yet.
