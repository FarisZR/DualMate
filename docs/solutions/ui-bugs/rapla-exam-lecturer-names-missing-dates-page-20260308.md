---
title: Rapla exam lecturer names missing on Dates page
date: 2026-03-08
---

# Summary

Rapla already parsed lecturer names for exam entries, but the Dates page dropped
that metadata before rendering important events. Generic exam rows such as
`Klausur` therefore gave students too little context to identify the module.

# Cause

- `lib/schedule/service/rapla/rapla_parsing_utils.dart` extracted `Personen:`
  into `ScheduleEntry.professor`.
- `lib/date_management/business/rapla_important_events_provider.dart`
  converted exam `ScheduleEntry` objects into `ImportantEvent` objects without
  preserving `professor`.
- `lib/date_management/ui/widgets/important_event_tile.dart` rendered only the
  event title and date.

# Fix

- `lib/date_management/model/important_event.dart`
  - add optional `professor` storage to the important-event model.
  - include the field in JSON serialization, equality, and hash code.

- `lib/date_management/business/rapla_important_events_provider.dart`
  - preserve `ScheduleEntry.professor` when mapping exam rows.
  - keep merged non-exam rows unchanged.

- `lib/date_management/ui/widgets/important_event_tile.dart`
  - show lecturer names as a secondary line for exam rows when available.
  - keep long lecturer strings to one truncated line so the Dates list stays
    compact.

- `lib/date_management/ui/widgets/important_event_section_card.dart`
  - suppress lecturer rendering on `Klausurwoche` section headers.

- `test/date_management/model/important_event_test.dart`
  - cover professor serialization and equality.

- `test/date_management/business/rapla_important_events_provider_test.dart`
  - cover professor preservation for exam entries.

- `test/date_management/ui/widgets/important_event_tile_test.dart`
  - cover exam-row rendering, non-exam suppression, and grouped header behavior.

# Validation

- `flutter test test/date_management/model/important_event_test.dart test/date_management/business/rapla_important_events_provider_test.dart test/date_management/ui/widgets/important_event_tile_test.dart`
- `flutter test test/date_management`
- `flutter test`

# Device check

- Built, installed, and launched on the connected Galaxy S21+ (`RFCR31468LJ`).
- Confirmed `com.fariszr.dualmate/.MainActivity` was running in the isolated
  feature worktree build during verification.
