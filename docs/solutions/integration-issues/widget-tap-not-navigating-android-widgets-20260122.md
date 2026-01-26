---
module: Android widgets (schedule/canteen)
date: 2026-01-22
problem_type: integration_issue
component: tooling
symptoms:
  - "Problem loading widget" shown for calendar widget
  - Widget taps highlight drawer item but do not switch content when app is in background
  - Logs show "Failed to navigate to: schedule" / "Failed to navigate to: canteen"
root_cause: config_error
resolution_type: code_fix
severity: medium
tags: [android-widget, remoteviews, deeplink, navigation]
---

# Troubleshooting: Widget taps not opening schedule/canteen

## Problem
Android home screen widgets for schedule/canteen failed to open the correct page. The schedule widget also showed "Problem loading widget" after layout changes.

## Environment
- Module: Android widgets (schedule/canteen)
- Affected component: widget RemoteViews + Flutter navigation
- Date: 2026-01-22

## Symptoms
- "Problem loading widget" appears for schedule widget.
- Tapping a widget only highlights the drawer entry, but content stays on the previous page.
- Flutter logs show "Failed to navigate to: schedule" / "Failed to navigate to: canteen".

## What Didn't Work

**Attempted Solution 1:** Adding schedule/canteen routes in the root router.
- **Why it failed:** This created duplicate `NavigatorKey.mainKey` instances and caused GlobalKey exceptions when the app was resumed.

**Attempted Solution 2:** Setting a PendingIntent on ListView inside the widget layout.
- **Why it failed:** RemoteViews ListView consumes touch events; the click intent never fired for the widget container.

## Solution

**1) Make widget layout clickable with a supported overlay**

- Add a `FrameLayout` overlay to each widget layout and attach the click intent to it.

```xml
<!-- android/app/src/main/res/layout/widget_schedule_now.xml -->
<FrameLayout
    android:id="@+id/widget_click_overlay"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@android:color/transparent"
    android:clickable="true"
    android:focusable="true" />
```

```kotlin
// android/.../widget/now/ScheduleNowWidget.kt
views.setOnClickPendingIntent(
    R.id.widget_click_overlay,
    PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java).apply {
            action = "com.fariszr.dualmate.OPEN_SCHEDULE"
        },
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )
)
```

**2) Route widget intents through a MethodChannel and apply in Flutter**

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
private var pendingRoute: String? = null
private var navigationChannel: MethodChannel? = null

override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    AndroidScheduleTodayWidget(applicationContext).setupMethodChannel(flutterEngine)

    navigationChannel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "com.fariszr.dualmate/navigation"
    )

    navigationChannel?.setMethodCallHandler { call, result ->
        when (call.method) {
            "getLaunchRoute" -> result.success(pendingRoute)
            "clearLaunchRoute" -> { pendingRoute = null; result.success(null) }
            else -> result.notImplemented()
        }
    }

    queueRoute(routeFromIntent(intent))
}

override fun onNewIntent(intent: android.content.Intent) {
    super.onNewIntent(intent)
    this.intent = intent
    queueRoute(routeFromIntent(intent))
}
```

```dart
// lib/ui/root_page.dart
static const MethodChannel _navigationChannel =
    MethodChannel('com.fariszr.dualmate/navigation');

void _applyPendingRoute() {
  if (_pendingRoute == null) return;
  final navigator = NavigatorKey.mainKey.currentState;
  if (navigator == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPendingRoute());
    return;
  }

  navigator.pushNamedAndRemoveUntil(_pendingRoute!, (route) {
    return route.settings.name == "schedule";
  });
  _pendingRoute = null;
}
```

**3) Keep root routing on `main` only**

- Avoid adding schedule/canteen routes to the root router to prevent duplicate Navigator keys.

## Why This Works

- RemoteViews only supports a limited set of layout types; using a `FrameLayout` overlay avoids unsupported view errors that cause "Problem loading widget".
- Widget ListViews consume taps; attaching the PendingIntent to a full-size overlay guarantees the click intent fires.
- Routing through a MethodChannel ensures that when the app is already running, the nested navigator receives the route and updates the content, not just the drawer highlight.

## Prevention

- Keep widget layouts within supported RemoteViews classes (FrameLayout, RelativeLayout, TextView, ListView).
- Always set widget click intents on a dedicated overlay instead of ListView.
- Route widget deep links through a single navigation channel instead of adding root routes that duplicate nested navigators.

## Related Issues

No related issues documented yet.
