---
title: fix: Enable Android widget scrolling and schedule item navigation
type: fix
date: 2026-01-27
---

# fix: Enable Android widget scrolling and schedule item navigation

## Overview

🐛 Fix Android home screen widgets so schedule and canteen lists are scrollable and never hide loaded items. Add schedule widget item taps that open the app and show the selected class details, while keeping day-column taps as the quick-open affordance.

## Problem Statement / Motivation

- Schedule and canteen widgets sometimes show scrollbars but do not scroll because the overlay click target intercepts touch.
- `MultiDayViewsFactory` trims rows based on widget height, so extra data is hidden instead of being scrollable.
- Schedule widgets do not support tapping a class to open its details; taps only open the app at the schedule view.

## Stakeholders

- End users: faster access to full widget data and entry details.
- Android widget maintainers: reduce widget UX complaints and support requests.
- Schedule feature owners: need reliable deep-link handling into entry details.

## Proposed Solution

### 1) Make widget lists actually scrollable

- Remove full-screen click overlay interception and rely on list item click templates.
- Stop trimming rows by widget height in `MultiDayViewsFactory`; rely on ListView scroll for overflow.
- Keep per-row overflow trimming optional (if needed later) but default to showing all items.

### 2) Add list item and day-column click handling

- Use `setPendingIntentTemplate` on list views and `setOnClickFillInIntent` on:
  - Day column container: opens the app to schedule (and optionally the week of the tapped date).
  - Schedule item container: opens app + selected class detail.
- Keep canteen widget scrollable; day column tap can open canteen for parity.

### 3) Deep-link schedule entries into the app

- Extend the Android → Flutter navigation bridge to accept a schedule-entry payload.
- Store a pending entry payload in `MainActivity` alongside the pending route.
- In Flutter, consume the payload and:
  - Navigate to the schedule page
  - Ensure the week containing the entry is loaded
  - Show `ScheduleEntryDetailBottomSheet` for the entry

## Technical Considerations

- **RemoteViews constraints:** must keep widget layouts to supported views and use collection click templates instead of overlays.
- **Navigation:** avoid adding new root routes; use the existing MethodChannel (`com.fariszr.dualmate/navigation`) and apply inside `NavigatorKey.mainKey`.
- **Identity:** prefer schedule entry `id` if available; otherwise fall back to `(start, end, title, details, professor)` matching.
- **Scroll behavior:** ensure overlays do not block ListView scroll gestures.
- **Resizes:** keep `onAppWidgetOptionsChanged` refresh hooks intact.

## Open Questions & Assumptions

- Assumption: schedule entry `id` from Android DB matches Flutter DB and can be used for lookup.
- Assumption: day-column tap should open schedule view without selecting a class (optionally shift to that week).
- Assumption: canteen items in a specifc day and the day column opens the canteen view for that day.
- Fallback: if entry lookup fails, open schedule view without a selected entry.

## Implementation Notes

**Android widget click + scroll updates**

- Update `android/app/src/main/kotlin/com/fariszr/dualmate/widget/MultiDayViewsFactory.kt` to return all rows (remove height-based trimming) and avoid forced overflow view when scroll is available.
- Update `android/app/src/main/kotlin/com/fariszr/dualmate/widget/today/ScheduleTodayWidget.kt` to set a `PendingIntentTemplate` on `R.id.schedule_entries_list_view` and remove use of `R.id.widget_click_overlay`.
- Update `android/app/src/main/kotlin/com/fariszr/dualmate/widget/now/ScheduleNowWidget.kt` to set a `PendingIntentTemplate` on `R.id.schedule_entries_list_view` and remove use of `R.id.widget_click_overlay`.
- Update `android/app/src/main/kotlin/com/fariszr/dualmate/widget/canteen/CanteenTodayWidget.kt` to set a `PendingIntentTemplate` on `R.id.canteen_entries_list_view` and remove use of `R.id.widget_click_overlay`.
- Update `android/app/src/main/res/layout/widget_day_row.xml` to add a dedicated day-column container id for click handling (e.g., `@+id/day_header_container`).
- Confirm `android/app/src/main/res/layout/widget_schedule_today.xml`, `android/app/src/main/res/layout/widget_schedule_now.xml`, and `android/app/src/main/res/layout/widget_canteen_today.xml` no longer rely on `widget_click_overlay` for taps.

**Per-item intents for schedule entries**

- Update `android/app/src/main/kotlin/com/fariszr/dualmate/widget/today/ScheduleEntryViewsFactory.kt` to:
  - Set `setOnClickFillInIntent` on the day header container (open schedule).
  - Set `setOnClickFillInIntent` on `R.id.layout_schedule_item` with extras for entry details (open specific class).
- Update `android/app/src/main/kotlin/com/fariszr/dualmate/widget/now/NowScheduleEntryViewsFactory.kt` with the same fill-in intent logic.
- Keep `android/app/src/main/kotlin/com/fariszr/dualmate/widget/canteen/CanteenEntryViewsFactory.kt` day-column fill-in intent for opening canteen (optional, but recommended for parity).

**Navigation bridge + Flutter handling**

- Update `android/app/src/main/kotlin/com/fariszr/dualmate/MainActivity.kt` to parse schedule-entry extras and send them over the navigation MethodChannel.
- Add a Flutter-side payload store (e.g., `lib/common/util/launch_intent.dart` or a new `lib/common/util/widget_navigation_payload.dart`) to hold pending schedule-entry data.
- Update `lib/ui/root_page.dart` to fetch and apply the pending entry payload after routing to schedule.
- Update `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart` to:
  - Detect a pending entry payload
  - Load the correct week if needed
  - Open `ScheduleEntryDetailBottomSheet` for the matched entry

### Pseudo code

```kotlin
// android/app/src/main/kotlin/com/fariszr/dualmate/widget/today/ScheduleEntryViewsFactory.kt
val openScheduleIntent = Intent().apply {
    action = "com.fariszr.dualmate.OPEN_SCHEDULE"
    putExtra("schedule_entry_id", item.id)
    putExtra("schedule_entry_start", item.start.toEpochSecond(zoneOffset))
    putExtra("schedule_entry_end", item.end.toEpochSecond(zoneOffset))
    putExtra("schedule_entry_title", item.title)
    putExtra("schedule_entry_details", item.details)
    putExtra("schedule_entry_professor", item.professor)
    putExtra("schedule_entry_room", item.room)
    putExtra("schedule_entry_type", item.type)
}
views.setOnClickFillInIntent(R.id.layout_schedule_item, openScheduleIntent)
```

```dart
// lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart
void _handlePendingWidgetEntry(WidgetScheduleEntryPayload payload) async {
  await viewModel.openWeekContaining(payload.start);
  final entry = await viewModel.resolveEntry(payload);
  if (entry != null && mounted) {
    _onScheduleEntryTap(context, entry);
  }
}
```

## Acceptance Criteria

- [ ] Schedule Today and Schedule Now widgets scroll to reveal all rows/items when height is constrained.
- [ ] Canteen widget scrolls to reveal all meals when height is constrained.
- [ ] Tapping a schedule item opens the app and shows the correct `ScheduleEntryDetailBottomSheet`.
- [ ] Tapping the day column opens the app to the schedule view (and optionally shifts to that week).
- [ ] Widget scroll gestures are not blocked by overlays.
- [ ] Resize still refreshes data via `onAppWidgetOptionsChanged`.
- [ ] Empty/purchase states still render without crashes.
- [x] `flutter test` passes.
- [ ] Manual verification on a real Android device using `flutter run -d <DEVICE_ID>` with widget resize + scroll + tap flows.

## Success Metrics

- 100% of loaded widget entries accessible via scroll on small widget sizes.
- No reports of “scrollbar but no scroll” for schedule/canteen widgets after release.
- Class taps consistently open the correct detail sheet in both cold and warm app starts.

## Dependencies & Risks

- **Launcher differences:** some launchers handle collection scrolls differently; test on stock Android and OneUI if possible.
- **Entry identity:** mismatch between Android widget DB ids and Flutter entries could open the wrong class.
- **Gesture conflicts:** removing overlays may reduce “tap anywhere to open” behavior; day-column taps should compensate.
- **Timing:** schedule data may not be loaded when deep link arrives; must queue and apply after load.

## References & Research

**Internal references**

- `android/app/src/main/kotlin/com/fariszr/dualmate/widget/MultiDayViewsFactory.kt`
- `android/app/src/main/kotlin/com/fariszr/dualmate/widget/MultiDayWidgetHelper.kt`
- `android/app/src/main/kotlin/com/fariszr/dualmate/widget/today/ScheduleTodayWidget.kt`
- `android/app/src/main/kotlin/com/fariszr/dualmate/widget/now/ScheduleNowWidget.kt`
- `android/app/src/main/kotlin/com/fariszr/dualmate/widget/canteen/CanteenTodayWidget.kt`
- `android/app/src/main/res/layout/widget_day_row.xml`
- `android/app/src/main/res/layout/widget_schedule_today.xml`
- `android/app/src/main/res/layout/widget_schedule_now.xml`
- `android/app/src/main/res/layout/widget_canteen_today.xml`
- `android/app/src/main/kotlin/com/fariszr/dualmate/MainActivity.kt`
- `lib/ui/root_page.dart`
- `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart`

**Institutional learnings**

- `docs/solutions/ui-bugs/widget-resize-and-canteen-duplication-20260127.md`
- `docs/solutions/integration-issues/widget-tap-not-navigating-android-widgets-20260122.md`

**External research**

- Not required; repo has established patterns for RemoteViews + widget navigation.

## AI-Era Considerations

- Keep all new navigation paths explicit and reviewable; avoid “magic” deep links.
- Favor small, testable increments (TDD where possible) before wiring full widget intent flow.
- Track manual device verification steps in the PR description for fast human review.
