---
module: Developer Experience
date: 2026-02-07
problem_type: developer_experience
component: development_workflow
symptoms:
  - "Developer options and performance overlay visible in production builds"
  - "Performance overlay toggle not persisting correctly or difficult to access"
root_cause: config_error
resolution_type: code_fix
severity: medium
tags: [developer-options, performance-overlay, debug-mode, settings]
---

# Troubleshooting: Developer Options and Performance Overlay

## Problem
The app lacked a dedicated area for developer tools, and the performance overlay toggle was either missing or risked being exposed in production builds. Additionally, the overlay state needed to persist across restarts but only for debug builds.

## Environment
- Module: Settings & Developer Experience
- Affected Component: Settings Page, PerformanceOverlayController
- Date: 2026-02-07

## Symptoms
- No easy way to enable `checkerboardOffscreenLayers` or `showPerformanceOverlay` at runtime.
- Risk of shipping debug toggles to end users if not properly guarded.
- Overlay state resetting on every app launch made profiling tedious.

## Solution

1. Added a hidden "Developer Options" section in Settings, revealed by tapping the "About" tile 7 times (Android-style).
2. Implemented `PerformanceOverlayController` to manage the overlay state and persistence.
3. Guarded the entire section and the controller logic with `kDebugMode` to ensure it compiles out or no-ops in release builds.

**Code changes** (Dart):

```dart
// lib/ui/settings/settings_page.dart
List<Widget> buildDeveloperSettings(BuildContext context) {
  if (!kDebugMode) return []; // Guard against release builds

  return [
    TitleListTile(title: L.of(context).settingsDeveloperTitle),
    // ... toggle widgets
  ];
}
```

```dart
// lib/common/logging/perf_overlay_controller.dart
class PerformanceOverlayController {
  static Future<void> load(PreferencesProvider prefs) async {
    if (!kDebugMode) return; // No-op in release
    // ... load logic
  }

  static Future<void> setEnabled(PreferencesProvider prefs, bool value) async {
    if (!kDebugMode) return; // No-op in release
    // ... save logic
  }
}
```

## Why This Works
- `kDebugMode` ensures the compiler can tree-shake or dead-code eliminate the developer blocks in release builds.
- The tap-to-unlock pattern prevents accidental activation by casual users even in debug/profile builds (though `kDebugMode` hides it entirely in release).
- Persistence allows developers to restart the app and immediately see the overlay for cold-start profiling.

## Prevention
- Always wrap developer-only UI code in `if (kDebugMode)` checks.
- Use a dedicated controller for dev-only preferences to centralize the logic and guards.
- Verify release builds do not contain the developer entry points.

## Related Issues
- See also: [schedule-calendar-slow-offline-freeze-20260206.md](../performance-issues/schedule-calendar-slow-offline-freeze-20260206.md)
