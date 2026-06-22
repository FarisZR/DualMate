---
module: Settings
date: 2026-06-22
problem_type: runtime_error
component: settings_startup
symptoms:
  - "NotRegisteredKiwiError while opening Settings immediately after startup"
  - "Failed to resolve TaskCallback for NextDayInformationNotification"
root_cause: deferred_startup_dependency_race
resolution_type: code_fix
severity: high
tags: [flutter, kiwi, settings, startup, notifications, android]
---

# Troubleshooting: Settings startup Kiwi TaskCallback race

## Problem

Opening Settings very quickly after app startup could render an empty gray page
and report a `NotRegisteredKiwiError` for the named
`NextDayInformationNotification` `TaskCallback`.

## Environment

- Module: Settings
- Platform: Android
- Affected Component: `SettingsPage` notification settings wiring
- Date: 2026-06-22

## Root Cause

The main app intentionally allows the first frame before deferred background
initialization completes. `NotificationApi`, `WorkSchedulerService`, and the
named next-day notification task are registered by that deferred path.

`SettingsPage` was still resolving notification dependencies while constructing
its state. A fast navigation to Settings could therefore beat background
registration. Checking `KiwiContainer.isRegistered` before `resolve` was not
sufficient protection for the race; the optional path also needed to tolerate a
not-registered error from the actual resolve call.

## Solution

Resolve only the always-available Settings dependencies eagerly. Resolve
notification dependencies through a defensive optional resolver, and hide the
notification section unless the real notification API, scheduler, and next-day
task are all available.

The fallback `SettingsViewModel` receives a no-op task and `VoidNotificationApi`
so non-notification settings remain usable during startup. Do not create or
register the real next-day task from `SettingsPage`; background initialization
owns task registration and scheduling.

## Verification

- `flutter test test/ui/settings test/common/appstart/background_initialize_test.dart`
- `flutter analyze lib/ui/settings/settings_page.dart test/ui/settings/settings_page_lifecycle_test.dart`
- Pixel 8 Pro cold-start fast navigation: force-stop app, launch, tap drawer,
  tap Settings before deferred background init completes, then confirm Settings
  renders and logcat has no `NotRegisteredKiwiError`, `Failed to resolve`, or
  `FATAL EXCEPTION`.

## Prevention

- UI routes should not assume deferred startup services are present.
- Treat Kiwi `isRegistered` as a hint, not a complete optional-resolve API.
- Keep background task construction and registration in startup/background
  initialization code, not in UI page constructors.
