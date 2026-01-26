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

## Solution

Added dispose-aware guards and cancellation in schedule view models to stop late notifications:

```dart
// weekly_schedule_view_model.dart
Future updateSchedule(DateTime start, DateTime end) async {
  if (_isDisposed) return;
  await _updateMutex.acquireAndCancelOther();
  if (_isDisposed) { _updateMutex.release(); return; }
  try {
    isUpdating = true;
    if (!_isDisposed) notifyListeners("isUpdating");
    await _doUpdateSchedule(start, end);
  } finally {
    isUpdating = false;
    _updateMutex.release();
    if (!_isDisposed) notifyListeners("isUpdating");
  }
}

Future _doUpdateSchedule(...) async {
  var cached = await scheduleProvider.getCachedSchedule(start, end);
  cancellationToken.throwIfCancelled();
  if (_isDisposed) return;
  _setSchedule(cached, start, end);
  var updated = await _readScheduleFromService(...);
  cancellationToken.throwIfCancelled();
  if (_isDisposed) return;
  ...
  if (!_isDisposed) notifyListeners("updateFailed");
}

void ensureUpdateNowTimerRunning() {
  if (_updateNowTimer == null || !_updateNowTimer!.isActive) {
    _updateNowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_isDisposed) return;
      notifyListeners("now");
    });
  }
}

@override
void dispose() {
  _isDisposed = true;
  _updateMutex.cancel();
  _updateNowTimer?.cancel();
  _errorResetTimer?.cancel();
  super.dispose();
}

// schedule_view_model.dart
_initialSetupTimer = Timer(const Duration(seconds: 1), () {
  if (_isDisposed) return;
  _scheduleSourceProvider.setupScheduleSource();
});

void onDidChangeScheduleSource(...) {
  if (_isDisposed) return;
  _didSetupProperly = valid;
  notifyListeners("didSetupProperly");
}

@override
void dispose() {
  _isDisposed = true;
  _initialSetupTimer?.cancel();
  _scheduleSourceProvider.removeDidChangeScheduleSourceCallback(onDidChangeScheduleSource);
  super.dispose();
}
```

Key changes: guard every timer/notify path with `_isDisposed`, cancel periodic timers and mutex token on dispose, and early-return during async refresh when disposed.

## Why This Works

PropertyChangeNotifier/ChangeNotifier warns when listeners are invoked after the notifier is disposed. Pending timers and async refreshes were firing after disposal. By marking `_isDisposed`, canceling timers/mutex tokens, and skipping notifications when disposed, no callbacks fire into torn-down widgets.

## Prevention
- Always guard async callbacks and timers in view models with a disposed flag before notifying listeners.
- Cancel periodic timers and in-flight mutex/cancellation tokens in `dispose()`.
- For long-running async refreshes, re-check `mounted/_isDisposed` after awaits before notifying.

## Related Issues
No related issues documented yet.
