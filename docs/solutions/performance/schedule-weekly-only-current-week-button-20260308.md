---
title: Simplify schedule page to weekly-only with contextual current-week button
date: 2026-03-08
---

# Summary

Issue #39 removed the daily schedule tab, collapsed the schedule route to a
single weekly surface, and added a contextual button to jump back to the
current week.

# Findings

1. `SchedulePage` still carried a two-tab `PagerWidget` shell even though widget
   payloads already opened the weekly flow.
2. The weekly page already had a `today` icon in the header, but it was always
   visible and easy to miss.
3. Recent schedule-performance work depended on keeping first render cache-first,
   preserving deferred weekly initialization, and avoiding extra work during
   active pager drags.

# Changes

- `lib/schedule/ui/schedule_page.dart`
  - removed the daily tab shell and now renders `WeeklySchedulePage` directly.
  - kept missing-source banner behavior and deferred weekly/filter warmup.
- `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart`
  - removed the always-visible header today action.
  - added a contextual current-week button that appears only after the user
    commits to a non-current week.
  - kept the existing weekly pager, `RepaintBoundary`, and low-draw swipe path.
- `lib/common/i18n/localizations.dart`
- `lib/common/i18n/localization_strings_en.dart`
- `lib/common/i18n/localization_strings_de.dart`
  - added localized copy for the new current-week control.
- removed daily-view-only files and tests that no longer participate in the
  schedule flow.
- `AGENTS.md`
  - updated schedule architecture notes to reflect weekly-only navigation.

# Validation

- `flutter test test/schedule/ui/schedule_page_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart`

# Device check

- Pending final live verification on the connected Galaxy S21+ (`RFCR31468LJ`).
