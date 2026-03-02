---
title: Remove startup notification permission prompt contention on S21
date: 2026-03-02
---

# Summary

Galaxy S21 cold starts still showed visible startup disruption because Android
notification runtime permission could grab focus during deferred background
initialization. Log captures previously showed very long
`Background init: notifications` times when that prompt path blocked.

This fix removes automatic notification permission prompting from startup and
keeps permission requests user-initiated from notification settings toggles.

# Changes

- `lib/common/appstart/app_initializer.dart`
  - startup notification permission policy now returns `false` via
    `shouldAutoRequestNotificationPermissionAtStartup()`.
  - background initialization still sets up notifications, but without runtime
    permission prompting.

- `lib/common/ui/notification_api.dart`
  - notification runtime permission request is now non-blocking during
    `initialize()` (`unawaited`).
  - added explicit `requestRuntimePermission()` API for user-initiated flows.
  - permission request failures are logged and handled as best effort.

- `lib/ui/settings/viewmodels/settings_view_model.dart`
  - when enabling next-day or schedule-change notifications, the app now
    requests notification runtime permission explicitly.
  - view model now depends on `TaskCallback` instead of concrete
    `NextDayInformationNotification` for simpler testing.

- `lib/ui/settings/settings_page.dart`
  - updated `SettingsViewModel` wiring for the constructor change.

- tests
  - `test/common/ui/notification_api_test.dart`
    - verifies initialize does not wait for permission completion.
    - verifies disabled startup permission path skips requests.
    - verifies permission request failures do not crash initialize.
  - `test/common/appstart/app_initializer_startup_policy_test.dart`
    - updated startup policy expectation: no auto notification permission
      request.
  - `test/ui/settings/viewmodels/settings_view_model_notification_permission_test.dart`
    - verifies permission request is triggered when enabling notification
      toggles.

# Device verification (S21)

- Device: `RFCR31468LJ`
- Cold-start probe after fix:
  - `Background init: notifications 3ms`
  - `Initialization finished 8ms`
  - no top-resumed `GrantPermissionsActivity` during steady-state probe
    (`MainActivity` remained focused).
- Integration tests on device:
  - `integration_test/drawer_switch_responsiveness_test.dart` passed.
  - `integration_test/onboarding_post_setup_navigation_stability_test.dart`
    passed.

# Validation

- `flutter analyze lib/common/ui/notification_api.dart lib/common/appstart/app_initializer.dart lib/ui/settings/viewmodels/settings_view_model.dart lib/ui/settings/settings_page.dart test/common/ui/notification_api_test.dart test/common/appstart/app_initializer_startup_policy_test.dart test/ui/settings/viewmodels/settings_view_model_notification_permission_test.dart`
- `flutter test test/common/ui/notification_api_test.dart test/common/appstart/app_initializer_startup_policy_test.dart test/common/ui/app_launch_dialogs_test.dart test/ui/settings/viewmodels/settings_view_model_notification_permission_test.dart`
- `flutter test integration_test/drawer_switch_responsiveness_test.dart -d RFCR31468LJ`
- `flutter test integration_test/onboarding_post_setup_navigation_stability_test.dart -d RFCR31468LJ`
