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

Made the sheet expandable so users drag it upward to reveal all details:

- `lib/schedule/ui/weeklyschedule/schedule_entry_detail_bottom_sheet.dart`
  - Replaced the fixed-height container with a `DraggableScrollableSheet`
    (`expand: false`, `initialChildSize: 0.4`, `minChildSize: 0.25`,
    `maxChildSize: 0.9`, `snap: true`, snap sizes `[0.4, 0.9]`).
  - Content is rendered inside a `SingleChildScrollView` driven by the sheet's
    `ScrollController`, so it scrolls and the sheet grows on drag.
  - Removed the now-redundant `package:flutter/widgets.dart` import.
- `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart`
  - Added `isScrollControlled: true` to `_onScheduleEntryTap`'s
    `showModalBottomSheet` so the sheet is allowed to occupy more screen height.

## Tests

`test/schedule/ui/weeklyschedule/schedule_entry_detail_bottom_sheet_test.dart`:

- Renders as a `DraggableScrollableSheet` with a scrollable body.
- A very long `details` string no longer throws a layout overflow
  (`tester.takeException()` is `null`) and the text is still present.
- The sheet is expandable: config allows growth past `initialChildSize`, and an
  upward fling visibly grows the sheet without dismissing it.
- Core fields (title, professor, details) render for a short entry.

## Notes

- Gesture feel (drag-to-expand snap points) is additionally verified on a real
  Android device per the project testing guidance.
- Material 3 bottom-sheet pattern (`DraggableScrollableSheet` inside
  `showModalBottomSheet` with `isScrollControlled: true`).
