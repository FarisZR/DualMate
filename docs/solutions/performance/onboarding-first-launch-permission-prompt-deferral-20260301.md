---
title: Defer first-launch permission prompts after onboarding
date: 2026-03-01
---

# Summary

After onboarding completion with a real Rapla URL, Pixel devices could stutter
heavily in the first seconds while permission prompts appeared. The startup
path also requested notification runtime permission immediately during deferred
background init, competing with onboarding-to-main transitions.

# Changes

- `lib/common/appstart/app_initializer.dart`
  - notification setup is now awaited.
  - notification runtime permission request is deferred on first launch using
    app launch count policy.
  - added helper `shouldRequestNotificationPermissionForLaunchCount`.

- `lib/common/appstart/notifications_initialize.dart`
  - added `requestRuntimePermission` argument to setup logic.

- `lib/common/ui/notification_api.dart`
  - `initialize()` now supports `requestRuntimePermission` flag.

- `lib/common/ui/app_launch_dialogs.dart`
  - app launch dialogs now run sequentially (`await` each).
  - exact alarm dialog is deferred until second launch with
    `shouldShowExactAlarmDialogForLaunchCount`.

- `lib/schedule/business/schedule_source_provider.dart`
  - `setupForRapla` now supports optional `clearCachedEntries` and `setupSource`
    flags.

- `lib/ui/onboarding/viewmodels/rapla_url_view_model.dart`
  - onboarding Rapla save now persists source settings without immediate cache
    clear/source setup to reduce finish-step pressure.

- tests
  - `test/common/appstart/app_initializer_startup_policy_test.dart`
    - added launch-count policy test for notification permission deferral.
  - `test/common/ui/app_launch_dialogs_test.dart`
    - added launch-count policy test for exact alarm dialog deferral.

# Device validation

- Pixel 8 Pro (`39181FDJG006DP`)
  - validated first-start onboarding flow using Rapla URL:
    `https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=eisenbiegler&file=TINF25B4`
  - verified first-launch lands in main schedule without immediate exact alarm
    prompt.
  - full integration suite passed on device.
