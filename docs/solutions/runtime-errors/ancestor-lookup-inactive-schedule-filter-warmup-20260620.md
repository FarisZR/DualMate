---
module: Schedule
date: 2026-06-20
problem_type: runtime_error
component: background_job
symptoms:
  - "Flutter runtime error: At this point the state of the widget's element tree is no longer stable"
  - "Provider.of lookup from _warmFilterPageState after deferred idle scheduling"
root_cause: async_timing
resolution_type: code_fix
severity: medium
tags: [flutter, provider, schedule, dispose, idle-task, filter-warmup]
---

# Troubleshooting: Ancestor lookup from deferred Schedule filter warmup

## Problem
Leaving or switching away from the Schedule page could log a Flutter runtime error from `_SchedulePageState._warmFilterPageState`. The deferred filter warmup ran from an idle scheduler task and tried to read `ScheduleViewModel` through `Provider.of(context)` after the element tree was no longer stable.

## Environment
- Module: Schedule
- Rails Version: N/A (Flutter)
- Affected Component: `SchedulePage` deferred filter warmup
- Date: 2026-06-20

## Symptoms
- Runtime error: `At this point the state of the widget's element tree is no longer stable.`
- Stack trace pointed to `Provider.of` inside `_warmFilterPageState`.
- The log appeared after deferred background or idle warmup work, not during the initial build.

## What Didn't Work

**Attempted Solution 1:** Guard the idle task with `mounted`.
- **Why it failed:** A Flutter element can still be mounted while ancestor lookup is unsafe during teardown or tree transitions. `mounted` prevents work after disposal, but it does not make `context` ancestor lookup safe in every deferred callback.

**Attempted Solution 2:** Move all visibility-driven deferred work into an extra post-frame scheduler.
- **Why it failed:** It fixed the exception, but changed the performance-optimized Schedule startup path and regressed week-swipe frame pacing. The scheduling behavior from `494740f3a57f2a8be40415d858742ad3106b9c7c` should be preserved.

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

Keep the visibility sync and schedule-source initialization paths unchanged from the performance-optimized implementation. The lifecycle bug is limited to the deferred filter warmup's late ancestor lookup, so the fix should be limited to that lookup.

## Why This Works

Flutter explicitly requires inherited-widget dependencies needed during teardown-sensitive code to be saved earlier, usually in `didChangeDependencies`. The idle task can now finish its warmup using an already captured view model instead of asking an inactive element to walk its ancestors.

## Prevention
- Do not call `Provider.of(context)`, `dependOnInheritedWidgetOfExactType`, or similar ancestor lookups from timers, scheduler tasks, or dispose-adjacent callbacks.
- Capture long-lived dependencies in `didChangeDependencies` or pass them directly into the async task.
- Keep `mounted` checks, but treat them as disposal guards, not as proof that inherited-widget lookup is safe.
- When fixing lifecycle exceptions in hot UI paths, prefer the smallest safe lifecycle change and verify frame timing before changing scheduling behavior.

## Related Issues
- See also: [notifylisteners-after-dispose-schedule-20260126.md](notifylisteners-after-dispose-schedule-20260126.md)
