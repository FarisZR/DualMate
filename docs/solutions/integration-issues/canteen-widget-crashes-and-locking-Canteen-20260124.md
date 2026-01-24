---
module: Canteen
date: 2026-01-24
problem_type: integration_issue
component: widget_provider
symptoms:
  - "Unhandled Exception: Http request failed for https://rapla..."
  - "Widget showing 'No upcoming events' on weekends"
  - "Failed assertion: line 5541 pos 12: '!_dirty': is not true"
  - "SQLiteDatabaseLockedException: database is locked"
root_cause: concurrency_and_state_management
severity: high
tags: [sqlite, widget, provider, background-task, flutter-android]
---

# Canteen Widget Crashes, Database Locking, and Data Refresh Issues

## Problem

The Canteen module experienced a cluster of stability issues affecting the Android Home Screen Widget and the main app:

1.  **Crash on Launch**: Opening the Canteen page caused a `!_dirty` assertion failure in `ChangeNotifierProvider`.
2.  **Database Locking**: The app would crash with `SQLiteDatabaseLockedException` when the widget tried to update while the app was open.
3.  **Missing Data**: The widget showed "No meals" on weekends, failing to show the next week's menu.
4.  **Background Crashes**: Unhandled HTTP exceptions in the background worker crashed the update task.

## Analysis

### 1. `!_dirty` Assertion (Flutter)
The `CanteenViewModel` called `notifyListeners()` (via `loadWeek`) inside its constructor. When `Provider` creates the ViewModel, it's in the middle of a build phase. Triggering a notification synchronously causes the `!_dirty` assertion because the widget tree is locked.

```dart
// OLD CODE
CanteenViewModel(this._provider) {
  _provider.addMenuUpdatedCallback(_onMenusUpdated);
  loadWeek(todayWeekStart); // <-- Triggers notifyListeners() immediately
}
```

### 2. Database Locking (Android/SQLite)
The main Flutter app opens the SQLite database in read-write mode. The Android Widget (running in a separate process/context) also attempted to open it with default flags (read-write). SQLite allows multiple readers but only one writer. When both tried to access it, the Widget's attempt failed with `SQLITE_BUSY`.

### 3. Widget Data Window (Kotlin)
The widget query logic calculated "current week" as "days remaining until Sunday". On Saturday, this returned only Saturday/Sunday. It did not fetch Monday's data, leaving the widget empty.

### 4. Background Exception (Dart)
The `BackgroundCanteenUpdate` task did not wrap the `_canteenProvider.refreshWeek` call in a try-catch. When the API failed (e.g., timeout), the exception propagated up and crashed the isolate.

## Solution

### 1. Defer State Updates
Wrapped initial data loading in `addPostFrameCallback` to ensure it runs *after* the build phase.

```dart
// NEW CODE (lib/canteen/ui/viewmodels/canteen_view_model.dart)
CanteenViewModel(this._provider) {
  _provider.addMenuUpdatedCallback(_onMenusUpdated);
  // Defer until build is done
  WidgetsBinding.instance.addPostFrameCallback((_) {
    loadWeek(todayWeekStart);
  });
}
```

### 2. Read-Only Widget Access
Modified the Android-native `ScheduleProvider` and `CanteenProvider` to open the database with `SQLiteDatabase.OPEN_READONLY`. This allows the widget to read data even while the Flutter app has a write lock.

```kotlin
// NEW CODE (android/.../database/CanteenProvider.kt)
return SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY)
```

### 3. Rolling 7-Day Window
Changed the widget helper to query a fixed 7-day range starting from today, regardless of the day of the week.

```kotlin
// NEW CODE (MultiDayWidgetHelper.kt)
fun weekDates(today: LocalDate): List<LocalDate> {
    return (0 until 7).map { offset -> today.plusDays(offset.toLong()) }
}
```

### 4. Background Error Handling
Added a try-catch block to the background task entry point.

```dart
// NEW CODE (lib/canteen/background/background_canteen_update.dart)
try {
  await _canteenProvider.refreshWeek(...);
} catch (e, trace) {
  print("Background canteen update failed: $e");
}
```

## Prevention

1.  **State Management**: Never trigger state changes (like `notifyListeners`) in a ViewModel constructor or `initState`. Always defer them.
2.  **Android/Flutter SQLite**: When accessing a Flutter-created SQLite DB from Android native code, **always** use `OPEN_READONLY` unless you implement a robust cross-process locking mechanism.
3.  **Widget Logic**: Test date ranges on weekends (edge cases) to ensure "next week" data is visible.
