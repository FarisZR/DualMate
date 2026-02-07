# Solution: Absolute Performance Optimization (Startup & Schedule)

## Problem Symptom
- Severe jank during app launch (skipped >120 frames).
- Frame drops when switching to the schedule tab (skipped >50 frames).
- Main thread stalls during heavy initialization (canteen refresh, calendar sync).
- UI freezes or shows stale data during background schedule updates.

## Investigation Steps
1. **Profiling**: Used Flutter DevTools and performance telemetry to identify hotspots in `_initializeApp` and `WeeklyScheduleViewModel`.
2. **Timing Analysis**: Found that blocking I/O (preferences, localization) and heavy data parsing (Rapla/Dualis) were happening on the main thread before the first frame.
3. **Lifecycle Audit**: Identified multiple `notifyListeners()` calls on disposed viewmodels and unhandled errors in timer-based refreshes.

## Root Cause Analysis
1. **Main-Thread Bloat**: Too many non-critical tasks were blocking `allowFirstFrame()`.
2. **Sync I/O**: Accessing shared preferences and loading localizations synchronously on startup.
3. **Lack of Concurrency**: Schedule parsing was not consistently offloaded to background isolates.
4. **Race Conditions**: Background fetches could complete after a user navigated away or changed the date range, leading to stale data being applied.

## Working Solution

### 1. Startup Path Tightening
- Moved non-critical work (canteen refresh, calendar sync) strictly after the first frame using `WidgetsBinding.instance.addPostFrameCallback`.
- Wrapped heavy foreground init in a run-once guard and offloaded it.
- Log prefixes were standardized to "Foreground heavy init:" for better visibility.

### 2. Isolate-Based Offloading
- Enforced isolate usage for schedule parsing and canteen scraping.
- Added a `PerformanceTelemetry` task system to track cache hits vs network fetches.

### 3. ViewModel Hygiene
- Implemented `notifyIfMounted(String property)` in `BaseViewModel` to prevent updates on disposed instances.
- Standardized async closures in timers and post-frame callbacks to await delays and catch errors.
- **Example**:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) async {
  if (_isDisposed) return;
  try {
    await Future.delayed(const Duration(milliseconds: 150));
    if (_isDisposed) return;
    await updateSchedule(currentDateStart, currentDateEnd);
  } catch (error, trace) {
    print("Refresh failed: $error");
  }
});
```

### 4. Staleness & Cancellation Guards
- Added checks in background refresh flows to ensure data matches the *current* view state before applying.
- Honors `CancellationToken` throughout the fetch pipeline.

### 5. Dependency Injection Refactoring
- Moved away from resolving dependencies via `KiwiContainer` inside methods.
- Injected required providers/repositories via constructor to improve testability and clarity.

## Prevention Strategies
- **CI Performance Monitoring**: Run profile builds and monitor frame skip counts.
- **Lint Rules**: Use custom lints (if added) to enforce `notifyIfMounted` over `notifyListeners`.
- **Review Checklist**:
  - [ ] Are heavy tasks offloaded to isolates?
  - [ ] Is `notifyIfMounted` used for async updates?
  - [ ] Are async closures guarded against disposal and errors?
  - [ ] Does background data validation handle date-range changes?

## Cross-References
- PR #19: fix: Absolute performance optimization
- docs/plans/2026-02-07-fix-absolute-performance-optimization-plan.md
- docs/solutions/runtime-errors/notifylisteners-after-dispose-schedule-20260126.md
