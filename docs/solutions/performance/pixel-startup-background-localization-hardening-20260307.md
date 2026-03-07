---
title: Remove startup background-scheduler localization crash on Pixel
date: 2026-03-07
---

# Summary

Pixel startup logs still showed a deferred background-init exception from Kiwi:
`Failed to resolve L`. The crash came from background task registration trying
to resolve localization from Kiwi during foreground startup, where localization
registration is intentionally deferred.

# Findings

1. `BackgroundInitialize.setupBackgroundScheduling()` constructed
   `NextDayInformationNotification` during foreground deferred startup.
2. `NextDayInformationNotification` required an injected `L` instance even
   though its localized strings are only needed when a notification is actually
   shown.
3. Foreground startup intentionally does not register `L` in Kiwi, so task
   construction could throw `NotRegisteredKiwiError`.

# Changes

- `lib/schedule/ui/notification/next_day_information_notification.dart`
  - removed the injected `L` dependency.
  - loads localization lazily from `PreferencesProvider` only when the task
    runs and needs notification text.
- `lib/common/appstart/background_initialize.dart`
  - stopped resolving `L` while registering background tasks.
- tests
  - `test/common/appstart/background_initialize_test.dart`
    - verifies background task registration succeeds without `L` in Kiwi.
  - `test/schedule/ui/notification/next_day_information_notification_test.dart`
    - verifies notification text still loads from preferences without Kiwi.

# Validation

- `flutter test test/common/appstart/background_initialize_test.dart test/schedule/ui/notification/next_day_information_notification_test.dart test/common/appstart/app_initializer_startup_policy_test.dart`
- `flutter analyze lib/common/appstart/background_initialize.dart lib/schedule/ui/notification/next_day_information_notification.dart test/common/appstart/background_initialize_test.dart test/schedule/ui/notification/next_day_information_notification_test.dart`

# Notes

- This removes the startup exception and a small amount of deferred startup work.
- The remaining Pixel frame drops in the shared log still point more toward
  schedule refresh/build churn and the canteen prewarm path than localization
  setup itself.
