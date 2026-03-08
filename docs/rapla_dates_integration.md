# Rapla Important Events Integration

## Overview
The Dates page now defaults to showing important events from Rapla for DHBW Karlsruhe.
Important events are exams, test weeks, and holidays. Users can switch back to
DHmine dates via a setting toggle.

## Implementation Details

### Data Sources
- Rapla: Fetched using `RaplaScheduleSource` with the stored Rapla URL.
- DHmine: Existing date management service remains available.

### Event Type Classification
Rapla event types are identified from the tooltip and the background color in
the Rapla HTML:

| Background Color | Tooltip Type | Resulting Type |
| --- | --- | --- |
| `#ff0000`, `#e2001a` | `Pruefung` | `ScheduleEntryType.Exam` |
| `#c0e2ff`, `#a3ddff` | `Sonstiger Termin` | `ScheduleEntryType.SpecialEvent` |
| `#cccccc`, `#ee61ff` | `Sonstiger Termin` | `ScheduleEntryType.PublicHoliday` |

The parsing logic is in `lib/schedule/service/rapla/rapla_parsing_utils.dart`.

### Important Event Provider
`RaplaImportantEventsProvider` fetches 3 years of Rapla data, filters the
important entries, de-duplicates identical items, merges consecutive entries
with the same title and type into a single `ImportantEvent` range, and caches
the last Rapla result for faster loads. The Dates page refreshes Rapla data in
the background on open. Exams are never merged.

`ImportantEventOrganizer` groups exams under their Klausurwoche range and
filters events that happen outside the study phases derived from
"Beginn der X. Theoriephase" and Klausurwoche events.

### Settings
Users can toggle the source under Settings:
- `Use DHmine for dates` (default: off)

The preference key is stored in `PreferencesProvider` as
`UseDhMineForDates`.

### UI
`DateManagementPage` switches between:
- Rapla important events list (default)
- Existing DHmine dates table

Each Rapla event shows a colored dot:
- Red: Exam
- Blue: Special event (test week, etc.)
- Gray: Holiday

Klausurwoche entries appear as section headers with nested exam rows underneath.
Exam rows show lecturer names when Rapla provides `Personen:` metadata.
Events outside of detected study phases are hidden by default; users can enable
them via the filter toggle on the Dates page.

## Tests

### Unit Tests
- `test/schedule/service/rapla/rapla_important_events_test.dart`
  - Uses fixture `test/schedule/service/rapla/html_resources/rapla_important_events_week.html`
  - Verifies event type classification based on background color.

- `test/date_management/model/important_event_test.dart`
  - Verifies `ImportantEvent` range handling and equality.

- `test/date_management/business/rapla_important_events_provider_test.dart`
  - Verifies filtering, merging, non-merging rules for exams, and lecturer
    preservation on exam rows.

- `test/date_management/ui/widgets/important_event_tile_test.dart`
  - Verifies lecturer names render on exam rows but not on non-exam rows.

- `test/date_management/ui/widgets/important_event_section_card_test.dart`
  - Verifies lecturer names are not shown on Klausurwoche section headers.

### Manual Testing (Android)
Run on a device with USB debugging enabled:

1. `flutter run` with the device connected.
2. Configure Rapla URL in Settings.
3. Open Dates page and verify:
   - Default Rapla list shows exams in red and test weeks in blue.
   - Holidays display in gray.
   - Exam weeks appear as section headers with nested exams.
   - Toggle "Outside study phases" to show hidden holidays.
   - Multi-day events show a date range.
4. Toggle `Use DHmine for dates` and confirm the DHmine table shows.
5. Disable network and confirm error handling.

## Issues and Debugging Notes
- If Rapla loads in the browser but fails in-app, verify the stored Rapla URL
  includes a valid scheme. The app defaults to HTTPS when no scheme is
  provided, and preserves all query parameters while overwriting only the
  date fields.
- Rapla hosts that require HARICA root certificates are handled via
  `RaplaHttpOverrides`. The override is applied in both the main isolate and
  the schedule isolate so HTTPS handshakes succeed on devices missing that
  root.
- If the calendar loads but the Dates page shows no Rapla events, partial
  schedule parsing errors no longer discard all data. The Dates view now uses
  any successfully parsed events and only falls back to cache when no
  important events were extracted.
