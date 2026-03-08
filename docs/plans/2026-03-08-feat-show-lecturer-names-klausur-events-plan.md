---
title: "feat: Show lecturer names for Rapla exam events"
type: feat
date: 2026-03-08
priority: medium
estimated_effort: 0.5-1 day
tags: [dates, rapla, exams, ui]
source_issue: 40
---

# feat: Show lecturer names for Rapla exam events

## Overview

Add lecturer names to individual Rapla exam rows on the Dates page so students can distinguish vague exam titles such as `Klausur`. This should apply to all Rapla events with `ScheduleEntryType.Exam`, while keeping the existing `Klausurwoche` grouping, pagination, and cache behavior unchanged.

## Problem Statement / Motivation

The Dates page currently loses lecturer metadata before rendering Rapla important events. `RaplaParsingUtils` already extracts lecturer names from the Rapla tooltip, but `RaplaImportantEventsProvider` drops that data when it converts `ScheduleEntry` records into `ImportantEvent` models, and `ImportantEventTile` only renders a title and date.

As a result, students can see an exam entry but still be unable to tell which module it belongs to when the title is generic or incomplete.

## Research Summary

### Research Decision

External research is not needed for this plan. The repository already contains the relevant data flow, UI patterns, and solution docs for this feature, and the requested change is a localized UI/data-mapping enhancement rather than a new framework or high-risk integration.

### Key Findings

- `lib/schedule/service/rapla/rapla_parsing_utils.dart:109` already extracts lecturer names into `ScheduleEntry.professor` from Rapla `Personen:` data.
- `lib/date_management/business/rapla_important_events_provider.dart:108` creates exam `ImportantEvent` objects without preserving lecturer data.
- `lib/date_management/model/important_event.dart:3` has no lecturer field today.
- `lib/date_management/ui/widgets/important_event_tile.dart:37` only renders title and formatted date.
- `lib/date_management/business/important_event_organizer.dart:27` groups exam rows under `Klausurwoche`; this behavior should remain untouched.

### Relevant Learnings

- `docs/solutions/ui-bugs/date-blocks-too-tall-20260202.md`
  - Keep the Dates list compact and avoid inflating cards unnecessarily.
- `docs/solutions/ui-bugs/first-load-dates-pagination-stops-3-months-20260202.md`
  - Avoid incidental changes to Rapla paging or first-load prefetch behavior.
- `docs/rapla_dates_integration.md`
  - Rapla dates are already intended to show grouped exam weeks and important-event rows fed from schedule data.

## Stakeholders

- Students using the Dates page to identify upcoming exams.
- Developers maintaining Rapla-to-Dates data mapping.
- QA/manual testers verifying Android behavior and locale rendering.

## Proposed Solution

### High-Level Approach

1. Extend `ImportantEvent` with optional lecturer metadata.
2. Preserve `ScheduleEntry.professor` when `RaplaImportantEventsProvider` maps exam entries.
3. Render lecturer names as visually secondary text on individual exam rows.
4. Do not show lecturer names for `Klausurwoche` headers or non-exam events.
5. If lecturer data is missing, keep the current layout without placeholder text.

### Recommended UX Behavior

- Treat the request as applying to all Rapla `ScheduleEntryType.Exam` events, not only titles that literally contain `Klausur`.
- Show lecturer text only on child exam rows, never on grouped section headers.
- Prefer plain secondary text over adding a new labeled field, unless product wants a stronger label later.
- Keep long lecturer strings constrained so tiles remain readable on narrow Android screens.

## Scope

### In Scope

- Rapla-backed exam rows on the Dates page.
- Data mapping from `ScheduleEntry.professor` to `ImportantEvent`.
- Widget and unit test updates for the changed model and rendering.
- Localization only if a visible label is introduced.

### Out of Scope

- Module inference or auto-renaming vague exam titles.
- DHmine dates.
- Room display.
- Changes to grouping, filtering, caching, pagination, or schedule screens.
- Reworking the Dates page layout beyond the extra lecturer line.

## Technical Considerations

- `ImportantEvent` serialization should stay backward-tolerant so older cached JSON without lecturer data still parses cleanly.
- Grouped `Klausurwoche` headers are rebuilt in `lib/date_management/business/important_event_organizer.dart`; they should keep empty lecturer metadata.
- Merged non-exam events should not inherit lecturer names, because merged rows can span multiple source entries.
- The tile layout should stay compact to avoid regressing the card-height fix documented in `docs/solutions/ui-bugs/date-blocks-too-tall-20260202.md`.
- If multiple lecturers are present, the first implementation should render the parsed Rapla string as-is rather than trying to normalize names.

## Acceptance Criteria

- [ ] `lib/date_management/model/important_event.dart` stores optional lecturer text for event rows.
- [ ] `lib/date_management/business/rapla_important_events_provider.dart` preserves `ScheduleEntry.professor` for all Rapla `ScheduleEntryType.Exam` items.
- [ ] `lib/date_management/ui/widgets/important_event_tile.dart` shows lecturer names on individual exam rows when lecturer text is non-empty.
- [ ] `lib/date_management/ui/widgets/important_event_section_card.dart` keeps `Klausurwoche` headers free of lecturer text.
- [ ] Non-exam Rapla events keep their current appearance.
- [ ] Exam rows without lecturer data render cleanly without placeholder text or broken spacing.
- [ ] Existing exam grouping and ordering remain unchanged.
- [ ] English and German layouts remain readable on narrow mobile screens.
- [ ] Automated tests cover model serialization/equality, provider mapping, and exam tile rendering.

## Implementation Outline

### Phase 1: Preserve Lecturer Metadata

**Files**

- `lib/date_management/model/important_event.dart`
- `test/date_management/model/important_event_test.dart`

**Tasks**

- Add an optional lecturer field such as `professor` or `lecturerNames` to `ImportantEvent`.
- Update constructor, `fromJson`, `toJson`, equality, and `hashCode`.
- Add test coverage for the new field so cache serialization remains explicit.

### Phase 2: Map Lecturer Data from Rapla

**Files**

- `lib/date_management/business/rapla_important_events_provider.dart`
- `test/date_management/business/rapla_important_events_provider_test.dart`

**Tasks**

- Pass `entry.professor` into `ImportantEvent` when mapping exam rows.
- Keep merged non-exam rows free of lecturer metadata.
- Add regression coverage to prove exam rows preserve lecturer data and still do not merge across days.

### Phase 3: Render Lecturer Names on Exam Tiles

**Files**

- `lib/date_management/ui/widgets/important_event_tile.dart`
- `lib/date_management/ui/widgets/important_event_section_card.dart`

**Tasks**

- Render lecturer text only when `event.type == ScheduleEntryType.Exam` and lecturer data is present.
- Keep lecturer text visually secondary to the title.
- Constrain long lecturer strings to avoid card-height blowups and awkward wrapping.
- Ensure grouped `Klausurwoche` headers remain unchanged.

### Phase 4: Add Widget Coverage

**Files**

- `test/date_management/ui/widgets/important_event_tile_test.dart`
- or `test/date_management/ui/date_management_page_test.dart`

**Tasks**

- Cover an exam row with lecturer data.
- Cover an exam row without lecturer data.
- Cover a non-exam row to confirm no UI regression.
- Cover a grouped `Klausurwoche` section to confirm only child exam rows show lecturers.

## SpecFlow Notes

### Primary User Flow

1. Student opens the Dates page.
2. Rapla important events load.
3. Student sees a generic exam row under `Klausurwoche` or as a standalone exam entry.
4. Lecturer names appear directly on the row.
5. Student uses the lecturer names to infer the correct module.

### Edge Cases

- Rapla exam row has no `Personen:` data.
- Rapla returns multiple lecturer names in one field.
- Lecturer string is long enough to wrap or truncate.
- Grouped `Klausurwoche` headers should not duplicate lecturer text.
- Non-exam items must remain unchanged.

### Recommended Boundaries

- Keep this as a display-only enhancement.
- Do not add module inference logic.
- Do not expand the feature to DHmine or schedule screens.
- Do not modify pagination, grouping, or caching logic unless tests prove it is necessary.

## Success Metrics

- Students can distinguish otherwise ambiguous Rapla exam rows on the Dates page.
- Existing Rapla grouping and paging behavior remain stable.
- New automated tests catch regressions in metadata preservation and tile rendering.
- Manual Android verification confirms readable layouts in both supported locales.

## Dependencies & Risks

- Lecturer names depend on Rapla providing `Personen:` tooltip data.
- Some source data may still be missing or inconsistent.
- Long lecturer strings may reduce scanability if not truncated carefully.
- Extending `ImportantEvent` changes its serialized shape, so null-safe parsing is required.

## Testing Plan

### Automated

- `test/date_management/model/important_event_test.dart`
- `test/date_management/business/rapla_important_events_provider_test.dart`
- `test/date_management/ui/widgets/important_event_tile_test.dart`

### Manual Android Verification

- Configure Rapla and open the Dates page.
- Verify exam rows show lecturer names when available.
- Verify rows without lecturer data still render cleanly.
- Verify holidays and special events are unchanged.
- Verify grouped `Klausurwoche` headers do not show lecturer text.
- Verify English and German layouts remain readable.

## References & Research

### Internal References

- `lib/schedule/service/rapla/rapla_parsing_utils.dart:109`
- `lib/date_management/business/rapla_important_events_provider.dart:108`
- `lib/date_management/model/important_event.dart:3`
- `lib/date_management/ui/widgets/important_event_tile.dart:37`
- `lib/date_management/ui/widgets/important_event_section_card.dart:60`
- `lib/date_management/business/important_event_organizer.dart:27`
- `test/date_management/business/rapla_important_events_provider_test.dart:122`
- `test/date_management/model/important_event_test.dart:6`

### Documentation

- `docs/rapla_dates_integration.md`
- `docs/solutions/ui-bugs/date-blocks-too-tall-20260202.md`
- `docs/solutions/ui-bugs/first-load-dates-pagination-stops-3-months-20260202.md`

### Related Work

- Related issue: `#40`
