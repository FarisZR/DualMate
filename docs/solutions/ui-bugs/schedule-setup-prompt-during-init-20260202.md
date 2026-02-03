---
module: Schedule UI
date: 2026-02-02
problem_type: ui_bug
component: initialization
symptoms:
  - "Schedule page briefly shows Rapla setup prompt even when Rapla is configured"
  - "Prompt flashes before the calendar loads"
root_cause: async_initialization
resolution_type: code_fix
severity: low
tags: [schedule, initialization, placeholder, flutter, ui]
---

# Troubleshooting: Schedule setup prompt flashes during initialization

## Problem
The schedule page briefly displayed the Rapla setup prompt before the calendar loaded, even when a valid Rapla configuration existed.

## Environment
- Module: Schedule UI
- Rails Version: N/A (Flutter)
- Affected Component: Schedule page initialization
- Date: 2026-02-02

## Symptoms
- The schedule setup call-to-action appears for a short moment on app start.
- The calendar renders correctly after the prompt disappears.

## What Didn't Work

**Attempted Solution 1:** Rely on the initial `didSetupProperly` value only.
- **Why it failed:** The schedule source initializes asynchronously, so the initial state was false while setup was in progress.

## Solution

Introduce an explicit initialization state in the schedule view model and show a neutral placeholder while setup runs.

**Code changes:**
```dart
// schedule_view_model.dart
bool _isInitializingScheduleSource = true;

void _scheduleInitialSetup() {
  _initialSetupTimer?.cancel();
  _initialSetupTimer = Timer(const Duration(seconds: 1), () {
    if (_isDisposed) return;
    _isInitializingScheduleSource = true;
    notifyListeners("isInitializingScheduleSource");
    _scheduleSourceProvider.setupScheduleSource().then((_) {
      if (_isDisposed) return;
      if (_isInitializingScheduleSource) {
        _isInitializingScheduleSource = false;
        notifyListeners("isInitializingScheduleSource");
      }
    });
  });
}

void onDidChangeScheduleSource(ScheduleSource scheduleSource, bool valid) {
  if (_isDisposed) return;
  _didSetupProperly = valid;
  if (_isInitializingScheduleSource) {
    _isInitializingScheduleSource = false;
    notifyListeners("isInitializingScheduleSource");
  }
  notifyListeners("didSetupProperly");
}
```

```dart
// schedule_page.dart
if (viewModel.isInitializingScheduleSource) {
  return Padding(
    padding: const EdgeInsets.all(32),
    child: ScheduleEmptyStatePlaceholder(),
  );
}
```

## Why This Works
The schedule source starts in an invalid state and becomes valid only after async setup. By guarding the UI with an initialization flag, the setup prompt is suppressed until setup completes, eliminating the misleading flash.

## Prevention
- For async setup, show a neutral placeholder until initialization completes.
- Avoid using initial configuration flags as final UI truth when setup is pending.

## Related Issues
- [notifylisteners-after-dispose-schedule-20260126](../runtime-errors/notifylisteners-after-dispose-schedule-20260126.md)
