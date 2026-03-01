---
title: Defer startup background prewarm until onboarding finishes
date: 2026-03-01
---

# Summary

Cold-start setup flow could still drop many frames right after finishing
onboarding because deferred startup work (background init, cache prewarm, and
foreground warmups) was scheduled from app boot time, not from post-onboarding
entry into main usage.

# Findings

1. Root startup always queued deferred initialization once first frame settled.
2. On first-start onboarding, those tasks could fire while user was still in
   setup or exactly during the transition to main pages.
3. The overlap increased frame pressure in the post-setup window.

# Changes

- `lib/ui/root_page.dart`
  - store deferred-init stopwatch and gate deferred initialization start.
  - when `isOnboarding == true`, attach a property listener and wait.
  - start deferred initialization only after onboarding flips to false.
  - detach onboarding listener on dispose and after start.

- `integration_test/onboarding_post_setup_navigation_stability_test.dart`
  - added real-device integration coverage for first-start flow:
    - finish onboarding,
    - perform first drawer switch to Dualis,
    - perform first drawer switch to Dates,
    - verify both pages open without transient exceptions.

# Validation

- `flutter analyze lib/ui/root_page.dart integration_test/onboarding_post_setup_navigation_stability_test.dart lib/ui/main_page.dart`
- `flutter test integration_test/onboarding_post_setup_navigation_stability_test.dart -d RFCR31468LJ`
- `flutter test integration_test/drawer_switch_responsiveness_test.dart -d RFCR31468LJ`
- `flutter test integration_test/date_management_startup_responsiveness_test.dart -d RFCR31468LJ`
