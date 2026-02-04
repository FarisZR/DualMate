---
title: fix: Schedule week view weekday columns
type: fix
date: 2026-02-04
---

# fix: Schedule week view weekday columns

## Overview
The weekly schedule grid sometimes shows empty columns for earlier weekdays even though lessons exist in those days. The goal is to ensure lessons from previous days of the same week are rendered correctly, while keeping the week view aligned to Monday through Friday (and only adding Saturday when there is at least one valid lesson on Saturday).

## Problem Statement / Motivation
- Lessons from earlier days in the same week sometimes do not render, leaving empty columns even though data exists.
- This breaks trust in the calendar and makes users think lessons are missing.
- The current day-range clipping and schedule trimming may be excluding valid entries from prior days in the displayed week.

## Proposed Solution
- Ensure the schedule query range always covers the full week window (Monday through Friday) for the currently displayed week.
- Prevent trimming or clipping from excluding entries that fall within the displayed week (especially earlier days).
- Keep the displayed range anchored to Monday through Friday, and include Saturday only when a valid Saturday lesson exists.
- Align day labels and column count so the labels always match visible columns.

## Technical Considerations
- `WeeklyScheduleViewModel` currently sets `clippedDateStart`/`clippedDateEnd` based on schedule start/end; this may exclude earlier-week entries if the schedule start is mid-week.
- `ScheduleWidget.buildEntryWidgets()` trims entries by column date range; ensure the schedule data covers the full displayed week so earlier days are not empty.
- Ensure that cached or partially refreshed schedules do not suppress entries for previous days.
- Use the same displayed range for both labels and entry layout to avoid mismatches.
- Keep Material 3 visual style; no UI redesign required.

## Acceptance Criteria
- [ ] Weekly schedule view always renders Monday through Friday columns, even when there are zero lessons or only mid-week lessons.
- [ ] Lessons that occur earlier in the week always render in their correct columns (no empty column when entries exist for that day).
- [ ] Saturday column appears only when at least one valid lesson occurs on Saturday within the week being displayed.
- [ ] Sunday is never displayed in the weekly grid.
- [ ] Day labels match visible columns (no extra labels for hidden days).
- [ ] Behavior is consistent for:
  - [ ] initial app open
  - [ ] previous/next week navigation
  - [ ] week opened from widget
  - [ ] offline/cached data
- [x] Add automated tests for date-range computation and week-coverage trimming behavior.
- [x] Manual verification on an Android device using `flutter run -d <DEVICE_ID>`.

## Success Metrics
- QA: 5/5 weeks checked show Mon-Fri only unless Saturday lessons exist.
- No regression in week navigation, tap handling, or schedule entry layout.

## Dependencies & Risks
- Risk of hiding legitimate Sunday lessons if they exist in data (confirmed not required for current scope).
- Misclassification of "valid" Saturday lessons could toggle the column incorrectly; define validity explicitly in code (non-canceled, non-hidden).
- If schedule fetching is limited to a narrower range, the UI will still show empty earlier days; ensure fetch range matches the displayed week.

## References & Research
### Internal References
- Week grid layout and labels: `lib/schedule/ui/weeklyschedule/widgets/schedule_widget.dart:54`
- Week date clipping and hours: `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:126`
- Date helpers for week boundaries: `lib/common/util/date_utils.dart:91`

### Related Learnings
- `docs/solutions/ui-bugs/swipe-unloaded-week-no-fetch-schedule-ui-20260127.md`
- `docs/solutions/ui-bugs/rapla-events-not-loading-first-open-schedule-20260128.md`
- `docs/solutions/ui-bugs/schedule-setup-prompt-during-init-20260202.md`

## AI-Era Notes
- Local repo research used to identify week grid computation and clipping logic.
- SpecFlow analysis highlighted missing weekday and weekend inclusion rules.
