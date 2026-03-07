---
title: Defer root preference gating and initial section mount on Pixel startup
date: 2026-03-07
---

# Summary

Pixel 8 Pro cold starts still showed a large startup-adjacent hitch after the
localization fix. The remaining pressure came from routing into the main shell
and mounting the first section while startup preference loading was still in the
critical path.

# Changes

- `lib/common/ui/viewmodels/root_view_model.dart`
  - tracks when startup preferences have actually loaded.
  - keeps the default theme/onboarding values until the async preference read
    completes, then notifies a dedicated `hasLoadedPreferences` property.

- `lib/ui/root_page.dart`
  - stops awaiting root preference loading on the first-frame path.
  - keeps a lightweight startup placeholder visible until preferences finish,
    then starts deferred background initialization from the post-load state.

- `lib/ui/main_page.dart`
  - defers mounting the initial navigation section for a short startup window.
  - keeps app bar actions disabled until the active section is mounted.
  - adds a test-only switch to suppress launch dialogs in widget tests.

- tests
  - `test/common/ui/viewmodels/root_view_model_test.dart`
    - verifies root preferences update theme/onboarding state and mark startup
      preference loading complete.
  - `test/ui/main_page_startup_placeholder_test.dart`
    - verifies the main shell shows a startup placeholder before mounting the
      first section, then mounts the requested section after the delay.

# Validation

- `flutter analyze lib/ui/root_page.dart lib/common/ui/viewmodels/root_view_model.dart lib/ui/main_page.dart test/common/ui/viewmodels/root_view_model_test.dart test/ui/main_page_startup_placeholder_test.dart`
- `flutter test test/common/ui/viewmodels/root_view_model_test.dart test/ui/main_page_startup_placeholder_test.dart test/common/data/preferences/preferences_access_test.dart`
- `flutter test test/common/appstart/app_initializer_startup_policy_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart`

# Device verification

- Device: Pixel 8 Pro `39181FDJG006DP`

Debug cold start after this pass:
- `Root init: base 208ms`
- `Root init: save language deferred 211ms`
- `Root init: allow first frame 212ms`
- `Root init: prefs 644ms`
- `Skipped 95 frames!`

Profile cold start after this pass:
- `Root init: base 1ms`
- `Root init: save language deferred 1ms`
- `Root init: allow first frame 1ms`
- `Root init: prefs 14ms`
- no `Failed to resolve L` / `KiwiError`
- no `Skipped ... frames` lines in the captured startup log

# Notes

- The debug build still shows a measurable cold-start hitch on the Pixel, but it
  improved from the prior `Skipped 107 frames!` probe and the profile build is
  now much closer to the seeded S21 baseline.
