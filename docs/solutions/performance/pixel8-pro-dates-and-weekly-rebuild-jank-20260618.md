---
title: Reduce Pixel 8 Pro dates animation and weekly schedule rebuild jank
date: 2026-06-18
type: fix
---

# Summary

Pixel 8 Pro profiling work found two avoidable sources of frame pressure in
interaction-heavy paths:

- Dates page exam rows started independent horizontal auto-scroll animations
  for professor names.
- Weekly schedule refresh/loading notifications could rebuild the whole page
  tree because the page listened to the full provider.

# Changes

- Replaced dates-page professor auto-scroll widgets with a single-line
  ellipsized `Text`, removing per-row timers, scroll controllers, and repeating
  `animateTo` work while the list is visible.
- Narrowed `WeeklySchedulePage` provider listening so header/current-week
  controls rebuild through property consumers instead of rebuilding the full
  page for unrelated loading/error updates.
- Cached weekly header date formatters per locale.

# Validation

- `flutter analyze lib/date_management/ui/widgets/important_event_tile.dart lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart test/date_management/ui/widgets/important_event_tile_test.dart`
- `flutter test test/date_management/ui/widgets/important_event_tile_test.dart`

# Device Notes

Pixel 8 Pro device authorization was restored after this code pass. Follow-up
profile-mode cold-launch navigation testing should continue from this
checkpoint.
