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
- **Exactly two settle states**: standard (`0.4`) and fully expanded (`0.9`).
  Releasing between them snaps to the nearer one (decided at the `0.65`
  midpoint). Dragging the sheet fully down to `min` (`0.25`) dismisses the modal.
- A `NotificationListener<ScrollEndNotification>` detects when the finger lifts
  (depth 0). The snap is run from a `WidgetsBinding.addPostFrameCallback` so it
  executes after the scrollable's own ballistic activity has started; the
  controller's `animateTo` then cancels that ballistic.
- Animation uses a snappy Material 3 decelerate (`Curves.easeOutCubic`) over
  **200 ms**, so the sheet locks into place quickly instead of slowly easing
  across (the earlier `easeInOutCubicEmphasized`/300 ms felt sluggish),
  per https://m3.material.io/styles/motion/transitions/transition-patterns and
  https://m3.material.io/foundations/usability/applying-m-3-expressive
- A `HapticFeedback.selectionClick()` fires every time the sheet **arrives** at
  either state — whether the snap animation drove it there or the user dragged
  it there by hand. This is implemented with a controller size-listener
  (`_onSizeChanged`) that fires exactly once per arrival (tracked via
  `_reachedState`), not only inside the snap path. The haptic is invoked
  fire-and-forget (with `catchError`) so a failing/absent platform handler can
  never block the snap animation.

### Snap guard must be cleared cancellation-safely

`DraggableScrollableController.animateTo` awaits an `AnimationController`
future. When the user drags the sheet mid-snap, the scrollable cancels that
animation via `AnimationController.stop()` whose default is `canceled: true`,
which leaves the underlying `TickerFuture`'s **primary** completer forever
pending (only `orCancel` errors). Awaiting it therefore never returns, so a
`try/finally` after the await would **never** run — the `_isSnapping` guard
would stick `true` after a single interrupted snap and suppress all later snaps
until the sheet was reopened.

The guard is therefore cleared from cancellation-safe paths, not from the
await:

- `_snapTo` is fire-and-forget (it does not `await animateTo`), so a never-
  completing future can neither hang nor leak the `State`.
- `_onSizeChanged` clears `_isSnapping` when the sheet arrives at a settle state
  (normal completion of the snap).
- A `ScrollStartNotification` handler clears `_isSnapping` when the user takes
  over (the interrupted-snap case).

## Tests

`test/schedule/ui/weeklyschedule/schedule_entry_detail_bottom_sheet_test.dart`
(now 9 tests):

- Renders as a `DraggableScrollableSheet` with a scrollable body.
- A very long `details` string no longer throws a layout overflow
  (`tester.takeException()` is `null`) and the text is still present.
- Starts at the standard size with `snap: false` and a max larger than initial.
- A partial upward drag (past the snap midpoint) snaps to the expanded size and
  emits a `HapticFeedbackType.selectionClick` (verified via a mocked
  `SystemChannels.platform` in `setUp`).
- **Manually dragging the sheet all the way to expanded (no snap) also fires a
  selection haptic** — proving the haptic is not tied to the snap path.
- A partial downward drag from expanded snaps back to standard and fires a
  haptic on arrival.
- **Snapping recovers after a snap is interrupted by a drag** (regression guard
  for the cancellation-safe `_isSnapping` reset above).
- Dragging the sheet far down dismisses the modal.
- Core fields (title, professor, details) render for a short entry.

Drag/snap assertions derive the expected sizes from the `DraggableScrollableSheet`
config (`maxChildSize` / `initialChildSize`) rather than hardcoding literals, so
they stay aligned with the widget contract.

## Notes

- The `HapticFeedback` platform channel is mocked in the test `setUp`/`tearDown`
  because, without a handler, `SystemChannels.platform.invokeMethod` returns a
  Future that never completes and would stall the snap in tests.
- Gesture feel (snap-points and haptics on a real device) is additionally
  verified on a real Android device per the project testing guidance.
- Material 3 bottom-sheet pattern (`DraggableScrollableSheet` inside
  `showModalBottomSheet` with `isScrollControlled: true`).
