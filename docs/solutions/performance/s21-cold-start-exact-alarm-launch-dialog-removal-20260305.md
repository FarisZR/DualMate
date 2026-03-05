---
title: Remove exact-alarm launch dialog from cold-start path on S21
date: 2026-03-05
---

# Summary

Galaxy S21+ cold starts were still perceived as unresponsive even after
notification-runtime permission startup deferral. The remaining blocker was the
exact-alarm launch dialog, which could still appear shortly after startup and
block interaction with the main screen.

# Findings

1. With main-flow seeded preferences, a cold-start UI probe on S21 showed an
   exact-alarm modal after startup (`Allow exact alarms`), which is
   non-dismissible by tapping outside and blocks page interaction.
2. The dialog came from `AppLaunchDialog.showAppLaunchDialogs(...)` via
   `shouldShowExactAlarmDialogForLaunchCount(...)`.
3. Even with first-launch deferral, `AppLaunchCount >= 1` made the modal appear
   on subsequent cold starts.

# Changes

- `lib/common/ui/app_launch_dialogs.dart`
  - disabled automatic exact-alarm dialog prompting on app launch by returning
    `false` from `shouldShowExactAlarmDialogForLaunchCount(...)`.
  - startup still executes other launch-dialog checks, but exact-alarm is no
    longer part of the cold-start critical path.

- `test/common/ui/app_launch_dialogs_test.dart`
  - updated policy test to assert exact-alarm dialog is never auto-shown at
    launch.

# Device validation (Galaxy S21+)

- Device: `RFCR31468LJ`
- Reproduced blocking state before fix with UI dump showing:
  - `Allow exact alarms`
  - `LATER` / `ALLOW` buttons
- After fix on profile build:
  - 5/5 seeded cold starts opened drawer interaction successfully after a
    1.2s post-launch tap.
  - 0/5 runs showed exact-alarm dialog.
  - startup probe showed `Open navigation menu` on main schedule screen without
    modal interception.

# Validation

- `flutter test test/common/ui/app_launch_dialogs_test.dart test/common/appstart/app_initializer_startup_policy_test.dart test/common/ui/notification_api_test.dart test/ui/settings/viewmodels/settings_view_model_notification_permission_test.dart`
- `flutter analyze lib/common/ui/app_launch_dialogs.dart test/common/ui/app_launch_dialogs_test.dart`
- `flutter test integration_test/drawer_switch_responsiveness_test.dart -d RFCR31468LJ`
- `flutter test integration_test/onboarding_post_setup_navigation_stability_test.dart -d RFCR31468LJ`
