---
module: Schedule UI
date: 2026-06-24
problem_type: ui_bug
component: frontend_flutter
sentry_issue: DUALMATE-G
symptoms:
  - "FlutterError: A RenderFlex overflowed by N pixels on the bottom"
  - "Long lesson details are cut off / unreadable in the detail bottom sheet"
  - "Schedule entry detail sheet has a fixed height that cannot grow"
root_cause: fixed_height_container_with_unbounded_column_content
resolution_type: code_fix
severity: high
tags: [schedule, weekly-calendar, ui, material3, bottom-sheet, sentry]
---

# Troubleshooting: Schedule entry detail bottom sheet overflowed with long details

## Problem

The lesson detail bottom sheet (`ScheduleEntryDetailBottomSheet`) used a fixed
`Container(height: 400)` wrapping a `Column`. When a `ScheduleEntry` had a long
`details` string, the column children no longer fit inside the 400px height and
Flutter threw `A RenderFlex overflowed by N pixels on the bottom`
(Sentry issue `DUALMATE-G`).

## Root Cause

- `showModalBottomSheet` returned a `Container(height: 400)` whose child `Column`
  had intrinsic, unbounded vertical content (the free-form `details` text).
- Nothing was scrollable, and the sheet could not grow, so any content taller
  than 400px overflowed.
- `showModalBottomSheet` was not configured with `isScrollControlled: true`,
  so even a taller child would have been capped by the default modal height.

## Fix

Made the sheet expandable so users drag it upward to reveal all details, with
Material 3-compliant snapping and haptics:

- `lib/schedule/ui/weeklyschedule/schedule_entry_detail_bottom_sheet.dart`
  - Replaced the fixed-height container with a `DraggableScrollableSheet`
    (`expand: false`, `initialChildSize: 0.4`, `minChildSize: 0.25`,
    `maxChildSize: 0.9`).
  - Content is rendered inside a `SingleChildScrollView` driven by the sheet's
    `ScrollController`, so it scrolls and the sheet grows on drag.
  - Removed the now-redundant `package:flutter/widgets.dart` import.
  - Converted to a `StatefulWidget` that drives snapping manually via
    `DraggableScrollableController.animateTo`. See "Snapping" below.
- `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart`
  - Added `isScrollControlled: true` to `_onScheduleEntryTap`'s
    `showModalBottomSheet` so the sheet is allowed to occupy more screen height.

## Snapping (Material 3 motion + haptics)

The built-in `DraggableScrollableSheet` snap uses a constant-velocity
(`_SnappingSimulation`) animation, i.e. it is linear. Its `snapAnimationDuration`
only changes the speed, never the curve, so it cannot match Material 3 motion
and emits no haptic. The fix therefore disables `snap` and snaps manually:

- `snap: false`; a `DraggableScrollableController` is held in state.
- A `NotificationListener<ScrollEndNotification>` detects when the finger lifts
  (depth 0). The snap is run from a `WidgetsBinding.addPostFrameCallback` so it
  executes after the scrollable's own ballistic activity has started; the
  controller's `animateTo` then cancels that ballistic.
- Target snap stop is the nearest of `0.25` (dismiss), `0.4` (medium) or `0.9`
  (large), decided at the midpoints between adjacent stops.
- Animation uses the Material 3 emphasized curve
  `Curves.easeInOutCubicEmphasized` over 300 ms, per
  https://m3.material.io/styles/motion/transitions/transition-patterns and
  https://m3.material.io/foundations/usability/applying-m-3-expressive
- A `HapticFeedback.selectionClick()` is fired on each snap. It is invoked
  fire-and-forget (with `catchError`) so a failing/absent platform handler can
  never block the snap animation.

## Tests

`test/schedule/ui/weeklyschedule/schedule_entry_detail_bottom_sheet_test.dart`
(now 7 tests):

- Renders as a `DraggableScrollableSheet` with a scrollable body.
- A very long `details` string no longer throws a layout overflow
  (`tester.takeException()` is `null`) and the text is still present.
- Starts at the medium size with `snap: false` and a max larger than initial.
- A partial upward drag (past the snap midpoint) snaps to the large size and
  emits a `HapticFeedbackType.selectionClick` (verified via a mocked
  `SystemChannels.platform` in `setUp`).
- A partial downward drag from the large size snaps back to the medium size.
- Dragging the sheet far down dismisses the modal.
- Core fields (title, professor, details) render for a short entry.

## Notes

- The `HapticFeedback` platform channel is mocked in the test `setUp`/`tearDown`
  because, without a handler, `SystemChannels.platform.invokeMethod` returns a
  Future that never completes and would stall the snap in tests.
- Gesture feel (snap-points and haptics on a real device) is additionally
  verified on a real Android device per the project testing guidance.
- Material 3 bottom-sheet pattern (`DraggableScrollableSheet` inside
  `showModalBottomSheet` with `isScrollControlled: true`).
