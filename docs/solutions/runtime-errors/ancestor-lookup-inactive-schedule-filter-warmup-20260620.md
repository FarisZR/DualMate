---
module: Schedule
date: 2026-06-20
problem_type: runtime_error
component: background_job
symptoms:
  - "Flutter runtime error: At this point the state of the widget's element tree is no longer stable"
  - "Provider.of lookup from _warmFilterPageState after deferred idle scheduling"
  - "Flutter assertion: !_dirty when Schedule setup notifies during provider mounting"
root_cause: async_timing
resolution_type: code_fix
severity: medium
tags: [flutter, provider, schedule, dispose, idle-task, filter-warmup]
---

# Troubleshooting: Ancestor lookup from deferred Schedule filter warmup

## Problem
Leaving or switching away from the Schedule page could log a Flutter runtime error from `_SchedulePageState._warmFilterPageState`. The deferred filter warmup ran from an idle scheduler task and tried to read `ScheduleViewModel` through `Provider.of(context)` after the element tree was no longer stable.

The running debug session also exposed a related `!_dirty` assertion when Schedule setup began from `didChangeDependencies` and synchronously notified listeners while provider elements were mounting.

## Environment
- Module: Schedule
- Rails Version: N/A (Flutter)
- Affected Component: `SchedulePage` deferred filter warmup
- Date: 2026-06-20

## Symptoms
- Runtime error: `At this point the state of the widget's element tree is no longer stable.`
- Stack trace pointed to `Provider.of` inside `_warmFilterPageState`.
- Debugger pause on `_AssertionError` with failed assertion `!_dirty` in `Element.rebuild`.
- The log appeared after deferred background or idle warmup work, not during the initial build.

## What Didn't Work

**Attempted Solution 1:** Guard the idle task with `mounted`.
- **Why it failed:** A Flutter element can still be mounted while ancestor lookup is unsafe during teardown or tree transitions. `mounted` prevents work after disposal, but it does not make `context` ancestor lookup safe in every deferred callback.

**Attempted Solution 2:** Start Schedule source initialization immediately from `didChangeDependencies`.
- **Why it failed:** `ScheduleViewModel.initialize()` notifies synchronously. Calling it while provider elements are still mounting can trip Flutter's `!_dirty` rebuild assertion.

## Solution

Cache the `ScheduleViewModel` reference in `didChangeDependencies`, while ancestor lookup is valid, and reuse that cached reference from deferred work.

```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  _scheduleViewModel = Provider.of<ScheduleViewModel>(context, listen: false);
}

Future<void> _warmFilterPageState() async {
  final scheduleViewModel = _scheduleViewModel;
  if (scheduleViewModel == null) return;
  // Continue warmup without Provider.of(context).
}
```

The same cached reference is also used when initializing the schedule source, keeping deferred setup code away from late ancestor lookups.

Defer the visibility sync that can start initialization until after the current frame:

```dart
void _syncDeferredWorkWithVisibilityAfterFrame() {
  if (_visibilitySyncPostFrameScheduled) return;
  _visibilitySyncPostFrameScheduled = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _visibilitySyncPostFrameScheduled = false;
    if (!mounted) return;
    _syncDeferredWorkWithVisibility();
  });
}
```

## Why This Works

Flutter explicitly requires inherited-widget dependencies needed during teardown-sensitive code to be saved earlier, usually in `didChangeDependencies`. The idle task can now finish its warmup using an already captured view model instead of asking an inactive element to walk its ancestors.

Separately, provider notifications now happen after the current build frame. This keeps synchronous `notifyListeners` calls out of provider mount/rebuild internals.

## Prevention
- Do not call `Provider.of(context)`, `dependOnInheritedWidgetOfExactType`, or similar ancestor lookups from timers, scheduler tasks, or dispose-adjacent callbacks.
- Capture long-lived dependencies in `didChangeDependencies` or pass them directly into the async task.
- Keep `mounted` checks, but treat them as disposal guards, not as proof that inherited-widget lookup is safe.
- If dependency changes need to start work that can notify providers, schedule that work post-frame.

## Related Issues
- See also: [notifylisteners-after-dispose-schedule-20260126.md](notifylisteners-after-dispose-schedule-20260126.md)
