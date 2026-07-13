---
title: "feat: Redesign Termine as a Material 3 academic agenda"
type: feat
date: 2026-07-13
priority: medium
estimated_effort: 2-4 days
tags: [ui, material-design-3, dates, rapla, accessibility, performance]
supersedes: docs/plans/2026-02-06-feat-redesign-dates-page-material-design-3-plan.md
---

# Redesign Termine as a Material 3 academic agenda

## Goal

Replace the current large, bubble-like cards with a cleaner agenda-style layout inspired by Google Calendar and Android Material 3. The page should remain a list of important academic dates rather than becoming a general calendar.

The redesign must preserve the existing Rapla loading, caching, pagination, refresh, grouping, and lazy-rendering behavior. This is primarily a presentation redesign with a small cleanup of the presentation model.

## Design references

### Current implementation

![Current Dates page](./assets/dates-material3-redesign/current-dates-page.png)

### Approved dark-mode direction

![Dark-mode Material 3 concept](./assets/dates-material3-redesign/dates-material3-dark.svg)

### Approved light-mode direction

![Light-mode Material 3 concept](./assets/dates-material3-redesign/dates-material3-light.svg)

The concept images communicate layout and hierarchy, not new data behavior. In particular, the collapsed multi-day RaPla notice must not be implemented unless recurrence semantics are introduced separately and safely.

## Current behavior confirmed in the codebase

### Repeated-event merging already exists

`RaplaImportantEventsProvider.mergeImportantEntries()` currently:

- groups entries by exact title and `ScheduleEntryType`;
- merges consecutive daily occurrences into one range;
- keeps entries separate when there is a date gap;
- never merges exams;
- ignores unrelated events between occurrences because each title/type group is evaluated independently.

Example: the same special event on 28, 29, and 30 September becomes one 28-30 September range even if another event also occurs on 29 September.

### Why the RaPla migration notice is currently repeated

The red RaPla notice shown in the current screenshot is parsed as `ScheduleEntryType.Exam` because Rapla classifies important entries primarily by color. Exams are deliberately excluded from merging, so the notice remains one row per day.

Do not add a text-specific exception for this notice. Guessing meaning from arbitrary event titles would be fragile and could incorrectly merge real exams or unrelated notices.

### Exam-week sections already exist

`ImportantEventOrganizer` detects a `SpecialEvent` whose normalized title contains `klausurwoche`. It then places exams whose start date falls within that event's date range under an `ImportantEventSection` header.

The current section key is based on normalized title, year, and half-year. This is sufficient for current fixtures but could theoretically merge two identically named exam-week ranges in the same half-year. The redesign should make section identity date-range-based while preserving current ordering.

### Existing performance structure is suitable

The page already uses:

- cached and refreshed Rapla windows;
- a prepared immutable `DatesRenderData` snapshot;
- `ListView.builder` and lazy row construction;
- flattening of large sections;
- scroll-position preservation;
- pull-to-refresh and automatic pagination;
- deferred initialization to protect drawer and startup responsiveness.

These should be retained. The relevant Dates test suite currently passes in full: 33 tests.

## Intended data behavior

### Keep as-is

- Genuine multi-day entries remain one range.
- Consecutive same-title, same-type non-exam entries may remain merged by the existing provider logic.
- Exams remain individual entries.
- Exam-week headers continue to group exams inside their date range.
- Unrelated events remain independent and chronologically visible.

### Do not add in this issue

- Generic recurrence detection.
- Title-based special cases for the RaPla migration notice.
- Automatic wording changes such as shortening arbitrary titles.
- A new calendar database or persistence schema.
- Changes to Rapla parsing colors or schedule notification behavior.

### Future-safe recurrence design

If recurrence summarization is added later, retain the original occurrences and create a separate presentation-level series summary. A summary must not replace or mutate the underlying events. This allows an event occurring between repeated dates to remain correctly ordered and visible.

## Proposed presentation model

### Explicit section semantics

Extend `ImportantEventSection` with an explicit semantic kind decided by `ImportantEventOrganizer`, for example:

- exam week;
- normal item;
- optional future group types.

The UI must not infer section meaning by searching titles for `klausur` or by checking colors.

### Structured date-rail data

Replace the single preformatted date string in `ImportantEventRenderData` with separate prepared fields needed by the new layout:

- weekday abbreviation;
- start day number;
- start month abbreviation;
- optional end day and month for ranges;
- time text;
- range/repetition subtitle where genuinely known;
- whether the left date rail should be shown for the row;
- category visual metadata.

Formatting stays in `DatesRenderData.prepare()`, not inside widgets. The widgets should remain simple renderers of immutable prepared state.

### Same-day rows

When multiple independent events share a date:

- show the date rail on the first row;
- keep subsequent rows aligned to the event column;
- do not merge the event cards merely because their dates match.

## UI implementation

### Layout

Each item uses two columns:

1. A fixed-width date rail containing weekday, large day number, and month.
2. A flexible event surface containing title, time, and optional lecturer information.

Exam-week sections use a standalone section heading followed by individual exam rows. They must not use one large enclosing card.

### Material 3 styling

- Use modest squircle/rounded-rectangle corners rather than pills.
- Use tonal containers with little or no elevation.
- Use spacing and thin dividers to establish hierarchy.
- Use a restrained exam accent and a separate special-event accent.
- Do not use `errorContainer` for exams; exams are important, not errors.
- Define domain-specific light and dark colors through a `ThemeExtension` instead of hardcoded colors in widgets.
- Use the existing Material 3 app theme and typography scale.

### Recommended widget structure

Replace the visual responsibilities of the current card widgets with focused components:

- section heading;
- date rail;
- event surface;
- agenda row;
- optional range rail.

`DateManagementPage`, the lazy list, and footer/loading behavior should remain structurally unchanged.

### Lecturer text

The model currently stores lecturers as one string. Preserve ellipsis behavior for long values. Do not display `+N weitere` until lecturer data is parsed into a reliable structured list.

## Files expected to change

### Business/model

- `lib/date_management/model/important_event_section.dart`
- `lib/date_management/business/important_event_organizer.dart`

### Presentation preparation

- `lib/date_management/ui/widgets/dates_render_data.dart`

### UI

- `lib/date_management/ui/date_management_page.dart`
- replace or substantially refactor:
  - `important_event_section_card.dart`
  - `important_event_section_row.dart`
  - `important_event_tile.dart`
- add focused agenda/date-rail widgets as needed.

### Theme/localization

- `lib/common/ui/colors.dart` or a dedicated Dates theme extension file.
- German and English localization resources for any new labels or accessibility descriptions.

## Test-first implementation plan

### Organizer and merge behavior

Add or preserve tests for:

- exams grouped under a valid exam-week range;
- exams outside the range remaining independent;
- two exam weeks with the same title in one half-year remaining separate;
- repeated non-exam entries merging only across consecutive days;
- a date gap splitting repeated entries;
- an unrelated event between repeated dates not being lost;
- exam entries never merging;
- the red RaPla migration notice remaining separate while classified as an exam.

### Render-data tests

Verify:

- German and English weekday/month formatting;
- single-day and multi-day rails;
- timed and all-day entries;
- same-day rail suppression for later rows;
- explicit section-kind propagation;
- past-state refresh scheduling remains correct.

### Widget tests

Cover:

- light and dark themes;
- phone widths from 320 to 600 logical pixels;
- tablet width without switching back to a non-lazy grid;
- text scaling up to at least 200%;
- long event names and lecturer strings;
- multiple events on one date;
- exam sections with zero, one, and many exams;
- multi-day ranges;
- semantic labels and minimum touch targets;
- lazy construction of large lists and flattened sections.

### Regression and device verification

Run:

- all `test/date_management/**` tests;
- `flutter analyze`;
- the Dates startup and cold-navigation integration tests;
- a profile-mode Android run on the connected device.

Check:

- no drawer or first-open jank regression;
- stable scroll position while additional Rapla windows load;
- no overflow at large text scales;
- correct colors and contrast in both themes;
- pull-to-refresh and pagination remain functional.

## Acceptance criteria

- The Dates page matches the approved agenda/date-rail direction in light and dark mode.
- Exam weeks appear as section headings with independent exam rows.
- Existing merge behavior is preserved; no title-specific RaPla workaround is introduced.
- The repeated RaPla notice remains separate unless its actual parsed type permits existing safe merging.
- Same-day and intervening events remain independently visible and correctly ordered.
- No loading, caching, refresh, pagination, or export behavior regresses.
- The page remains lazily rendered and meets the existing performance baselines.
- All Dates tests, analyzer checks, and device verification pass.

## Relationship to the older plan

The February 2026 Material 3 plan delivered important groundwork: empty states, tonal cards, dispose guards, and lazy rendering. This document supersedes its remaining visual direction. Completed infrastructure from that plan should be retained rather than reimplemented.
