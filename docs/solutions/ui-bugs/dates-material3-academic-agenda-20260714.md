---
title: Dates page Material 3 academic agenda
date: 2026-07-14
problem_type: feature
module: Dates
component: Rapla important-event agenda
severity: medium
symptoms:
  - Important dates were presented as generic grouped tiles instead of a scannable academic agenda
  - Exam-week markers were rendered as event cards rather than structural headings
  - Equal-time important events did not have one shared deterministic ordering contract
root_cause: The Dates presentation model mixed section structure with tile rendering and did not prepare the responsive, localized agenda fields needed by a lazy flat list
tags: [flutter, material3, dates, agenda, accessibility, performance]
---

## Context

The Rapla Dates view needed a Material 3 agenda treatment with a fixed date rail, event-category surfaces, explicit exam-week headings, responsive phone/tablet spacing, large-text support, and complete TalkBack labels. The redesign also had to retain the existing merge rules, paging behavior, list identity, and profile-mode performance.

## Investigation

- Confirmed that exam-week markers already existed in the organizer, but section identity was implicit and same-title ranges could be conflated.
- Traced provider ordering and merging to separate safe consecutive-day merging from the final deterministic order.
- Profiled the original and redesigned screens on a Samsung SM-G996B at 60 Hz with animation scales at `1.0`.
- Diagnostic traces showed no intrinsic layout or `saveLayer` work. The only Dates regression was concentrated in first-populated-list layout, where private stateless row wrappers increased visible-row build work.

## Solution

- Added explicit `standalone` and `examWeek` section kinds with exact range identity, empty exam-week retention, and deterministic shared event ordering.
- Prepared one immutable `DatesRenderData` snapshot containing localized date/range/time/semantics strings, stable item keys, and an O(1) key-to-index map.
- Replaced the grouped tile/card widgets with one flattened lazy agenda list, structural exam-week headings, a fixed date rail, filled category surfaces, and theme-extension colors for light and dark modes.
- Resolved responsive layout and text scaling once at the page boundary; rows use fixed-width/expanded primitives with no intrinsic measurement.
- Exposed one non-interactive semantics container per event and a level-two semantics header per exam week.
- Flattened private row helpers into one widget build and avoided offscreen prebuild work during the first reveal after trace-guided tuning.

## Follow-up corrections (2026-07-15)

- Indented exam-week event surfaces by 12 px beneath their structural heading so the rows read as children of that week while retaining the shared date rail.
- Added a distinct 28 px top-spacing role when the next event starts at least seven calendar days after the previous event ends; ordinary adjacent events retain 12 px spacing.
- Made every Rapla event row an accessible button and opened the same `ScheduleEntryDetailBottomSheet` used by Schedule. Important events now preserve details and room fields when converted to schedule entries.
- Replaced the bright generic outline token with dedicated agenda-divider colors (`#D8D8D8` light and `#3A3A3A` dark).
- Restored a small 140 px list cache extent and used an equivalent zero-elevation `MaterialType.card` surface instead of the redundant `Card` wrapper, reducing cold layout work without sacrificing Material ink feedback.
- Completed the important-event ordering key with the event's remaining stable identity and reused it for section anchors. Empty sections now clear the pending after-heading spacing state.

## Verification

- `flutter test test/date_management --reporter compact` — 61 tests passed.
- `flutter analyze` — no issues found.
- `integration_test/date_management_startup_responsiveness_test.dart` — passed on the connected Galaxy S21+.
- Same-device profile baseline/candidate comparison used three-run medians with deterministic fixtures; Dates cold launch, drawer navigation, and loaded-list scrolling reached their expected final states in every run.
- Awake baseline to candidate frame medians (p95/worst): cold launch `9.388/19.484 ms` to `8.486/20.807 ms`, drawer navigation `4.775/14.682 ms` to `5.494/13.199 ms`, and loaded-list scrolling `2.618/7.489 ms` to `3.033/6.672 ms`; all plan gates passed.
- Inspected diagnostic timelines for cold population, drawer navigation, and scrolling: no intrinsic passes, repeated formatting/normalization, `saveLayer`, or unexpected per-row layout probes were present.
- Android CLI layout inspection plus a device screen-recording frame confirmed the agenda on the physical Galaxy S21+ without overflow or Android runtime errors.
- Follow-up 120 Hz baseline/candidate medians on the same device (combined p95/worst): cold Dates launch `7.876/15.796 ms` to `9.073/17.045 ms`; loaded-list scrolling `1.906/6.463 ms` to `2.324/4.149 ms`. The scroll run had zero frames over 8.33 ms in all three candidate runs, no animation drops, and passed the baseline-derived regression gates.
- With Android Extra dim disabled, Android CLI screenshots confirmed the softened dividers. A profile-mode integration gesture opened the details sheet on-device, and Android CLI layout/screenshot inspection confirmed its title, time range, type, room, and details.

## Prevention

- Keep normalization, formatting, sorting, and semantics-label construction in snapshot preparation rather than visible-row builds.
- Preserve direct stable keys and O(1) `findChildIndexCallback` lookup when changing pagination or list composition.
- Re-run the same-device three-run profile comparison after increasing row structure, cache extent, clipping, or layer count.
- Keep decorative icons and duplicate visual rail text excluded from accessibility semantics.

## Related

- Plan: `docs/plans/2026-07-13-feat-redesign-dates-agenda-material3-plan.md`
