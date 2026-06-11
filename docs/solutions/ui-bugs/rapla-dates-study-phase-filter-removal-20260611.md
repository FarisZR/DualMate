---
module: Date Management
date: 2026-06-11
problem_type: ui_bug
component: Rapla important events
root_cause: brittle_filtering
resolution_type: code_fix
severity: medium
tags: [rapla, dates, filtering]
---

# Rapla Dates events disappeared after later refreshes

## Problem

The Dates page first showed the correct current-semester exams, then later
refreshes made them disappear once future Rapla events were loaded.

## Cause

`ImportantEventOrganizer` filtered Rapla important events through inferred
study phases. That inference depended on phase markers being present in the
loaded Rapla windows. When a window started after the current semester's
`Beginn` event but later loaded a future phase marker, current exams could be
treated as outside the detected phase and hidden.

## Fix

Remove study-phase suppression for Rapla important events. The organizer still
sorts events and groups Klausurwoche sections with nested exams, but it no
longer hides events based on inferred practice or theory phases.

Student-facing operational notices, such as Rapla migration warnings, remain
visible.

## Validation

- `flutter test test/date_management/business/important_event_organizer_test.dart`
- `flutter test test/date_management`
