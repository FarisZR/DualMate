---
module: Android widgets (schedule/canteen)
date: 2026-01-27
problem_type: integration_issue
component: navigation
symptoms:
  - "Widget day taps only work on cold start"
  - "Class/meal rows do nothing when tapped"
root_cause: lifecycle_gap
resolution_type: code_fix
severity: medium
tags: [android-widget, remoteviews, pendingintent, lifecycle, navigation]
---

# Troubleshooting: Widget item taps missing after resume

## Problem
Schedule/canteen widget taps only worked when the app was closed. When the app was running in the background, day taps no longer navigated to the correct week/day and class/meal taps did nothing.

## Environment
- Module: Android widgets (schedule/canteen)
- Affected component: RemoteViews click handling + Flutter navigation
- Date: 2026-01-27

## Symptoms
- Day taps route correctly only on cold start.
- Class/meal rows do not open the app at all.

## Root Cause
- Pending route/payload data was only pulled on startup. When the app was resumed, the MethodChannel call could be missed.
- Child views inside widget rows were focusable/clickable, which prevented the root item fill-in intent from firing reliably.

## Solution

**1) Re-fetch pending widget routes on resume**

Add a lifecycle observer to re-read launch route/payload whenever the app resumes.

```dart
// lib/ui/root_page.dart
class _RootPageState extends State<RootPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navigationChannel.setMethodCallHandler(_handleNavigationCall);
    _fetchLaunchRoute();
    _fetchLaunchPayload();
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchLaunchRoute();
      _fetchLaunchPayload();
    }
  }
}
```

**2) Make widget item roots the only clickable views**

Remove click handling from child views and set the fill-in intent on the item root only.

```xml
<!-- android/app/src/main/res/layout/widget_schedule_day_item.xml -->
<LinearLayout
    android:id="@+id/layout_schedule_item"
    android:clickable="true"
    android:descendantFocusability="blocksDescendants">
    ...
</LinearLayout>
```

```kotlin
// android/.../ScheduleEntryViewsFactory.kt
views.setOnClickFillInIntent(
    R.id.layout_schedule_item,
    Intent().apply {
        putExtra(WidgetNavigationExtras.scheduleEntryId, item.id)
        ...
    }
)
```

Apply the same pattern to canteen rows and remove fill-in intents from child text views.

## Why This Works
- Lifecycle re-fetch ensures pending launch data is applied even when MethodChannel calls are missed during resume.
- Root-only click handling prevents focusable children from swallowing widget taps.

## Prevention
- Always refresh pending widget intents on resume.
- Keep RemoteViews list items clickable at the root only.
