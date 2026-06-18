---
title: Eliminate Pixel 8 Pro 120Hz cold-navigation frame misses
date: 2026-06-18
type: fix
---

# Summary

Pixel 8 Pro traces must use the 120Hz frame budget. A frame below 16.67ms is
only clean for 60Hz; the relevant budget on this device is about 8.33ms.

Guarded cold-navigation profiling showed that the initial Schedule tab was
still starting weekly schedule initialization while the user had already moved
to Canteen or Dates. Because Schedule stays mounted in the main `IndexedStack`,
that deferred work could overlap fast post-launch page switches and produce
layout/raster bursts above the 120Hz budget.

# Changes

- Gate Schedule source setup, weekly cache initialization, and filter warmup on
  the Schedule tab being the active main-navigation section.
- Cancel pending Schedule startup timers when the user leaves the Schedule tab
  before they fire, and restart them when Schedule becomes visible again.
- Delay automatic visible-week refreshes while users are swiping across weeks,
  while keeping widget payload and manual refresh paths immediate.
- Prebuild adjacent Canteen pages before the first swipe.
- Pass known schedule entry dimensions into schedule cards to avoid per-card
  `LayoutBuilder` work during dense weekly layout passes.
- Drop schedule-card shadows in dense mobile cells to reduce raster pressure.
- Add `scripts/profile_flutter_timeline.py` for repeatable VM-service timeline
  summaries with explicit `>8.33ms` and `>16.67ms` counts.

# Validation

- `flutter analyze lib/schedule/ui/schedule_page.dart lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart lib/schedule/ui/weeklyschedule/widgets/schedule_widget.dart lib/schedule/ui/weeklyschedule/widgets/schedule_entry_widget.dart lib/canteen/ui/canteen_page.dart test/schedule/ui/schedule_page_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart test/canteen/ui/canteen_page_bounds_test.dart`
- `flutter test test/schedule/ui/schedule_page_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart test/schedule/ui/weeklyschedule/schedule_entry_widget_layout_test.dart test/canteen/ui/canteen_page_bounds_test.dart`
- `JAVA_HOME=/usr/lib/jvm/java-17-temurin-jdk flutter build apk --profile --no-pub`
- Pixel 8 Pro guarded cold journey with focus assertions after every major
  navigation step:
  - Trace: `/tmp/dualmate_120hz_guarded_visible_schedule_1.json`
  - `Frame`: max 7.61ms, `>8.33ms=0`, `>16.67ms=0`
  - `Animator::BeginFrame`: max 7.67ms, `>8.33ms=0`, `>16.67ms=0`
  - `BUILD`: max 4.21ms
  - `LAYOUT`: max 5.10ms
  - `GPURasterizer::Draw`: max 6.41ms

# Notes

The guarded run uses hamburger taps instead of edge swipes to avoid Android
system gesture ambiguity. It verifies `mCurrentFocus` remains
`com.fariszr.dualmate/com.fariszr.dualmate.MainActivity` throughout the trace.
