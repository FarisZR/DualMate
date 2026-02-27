---
title: fix: improve current-time indicator clarity in schedule calendar
type: fix
date: 2026-02-25
issue: 34
---

# fix: improve current-time indicator clarity in schedule calendar

## 🐛 Overview

The current-time cue in the weekly calendar is currently perceived as a subtle shade, not a clear line. This makes "now" hard to see unless it overlays lesson cards. This plan introduces a clear Material 3-aligned current-time indicator, hides it when now is outside visible hours, and preserves existing cache-first and lifecycle behavior.

## Problem Statement / Motivation

- Reported in `#34`: the calendar does not show a clear current-time line; current cue is hard to see.
- Current weekly UI uses a past overlay, which can look like a general tint instead of a specific "now" marker.
- When now is beyond the visible hour window, the current behavior can still leave a full-day shaded look, which does not match the requested behavior.
- The fix should improve clarity without obstructing lesson content and must remain consistent with Material 3 theming.

## Consolidated Research

### Internal architecture and code paths

- Weekly schedule renders a past-time overlay on top of the schedule surface:
  - `lib/schedule/ui/weeklyschedule/widgets/schedule_widget.dart:124`
  - `lib/schedule/ui/weeklyschedule/widgets/schedule_past_overlay.dart:62`
- Past overlay currently paints partial/full rectangles and clips to visible canvas:
  - `lib/schedule/ui/weeklyschedule/widgets/schedule_past_overlay.dart:80`
  - `lib/schedule/ui/weeklyschedule/widgets/schedule_past_overlay.dart:108`
- Visible hour bounds are explicitly computed in weekly view model:
  - `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:40`
  - `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:242`
  - `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:246`
- Weekly view already has minute-level "now" updates every minute:
  - `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:543`
- Material 3 is enabled globally; theme has explicit tint/surface rules:
  - `lib/common/ui/colors.dart:46`
  - `lib/common/ui/colors.dart:101`
  - `lib/common/ui/colors.dart:106`

### Institutional learnings applied

- Keep background updates from mutating visible schedule state:
  - `docs/solutions/ui-bugs/monday-lessons-missing-after-background-resume-20260210.md:27`
  - `docs/solutions/ui-bugs/monday-lessons-missing-after-background-resume-20260210.md:29`
- Preserve cache-first visible-week behavior while improving UI rendering:
  - `docs/rapla-cache-refresh-behavior.md:46`
  - `docs/rapla-cache-refresh-behavior.md:59`
- Use explicit Material 3 tint/surface handling for predictable visual results:
  - `docs/solutions/ui-bugs/dark-surface-tint-and-status-bar-icons-20260202.md:27`
  - `docs/solutions/ui-bugs/dark-surface-tint-and-status-bar-icons-20260202.md:47`
- Forced refresh/invalidation behavior must not regress while touching schedule UI:
  - `docs/solutions/ui-bugs/filters-dont-apply-calendar-without-interaction-20260209.md:34`

### External best-practice and framework research

- Non-text indicator contrast should meet at least 3:1, and text labels 4.5:1 when present.
- Avoid color-only signaling: pair line color with shape/semantic cue.
- Keep non-interactive overlays non-obstructive and avoid heavy repaint loops.
- Flutter guidance supports custom painter overlays plus minute-boundary updates.

References:

- WCAG non-text contrast: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html
- WCAG use of color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- Flutter accessibility guidance: https://docs.flutter.dev/ui/accessibility
- Flutter `CustomPainter`: https://api.flutter.dev/flutter/rendering/CustomPainter-class.html
- Flutter performance best practices: https://docs.flutter.dev/perf/best-practices
- Material 3 color roles: https://m3.material.io/styles/color/roles

### Research decision

External research was included because this issue asks for explicit Material 3 visual behavior and accessibility clarity, and local docs did not define a canonical "current-time line" pattern for weekly calendar rendering.

## ✨ Proposed Solution

Replace the weekly calendar's current-time cue from "mostly shade perception" to an explicit, high-contrast, Material 3-aligned current-time indicator line.

High-level approach:

1. Introduce a dedicated weekly current-time indicator overlay that maps now to exact minute position within visible hours.
2. Hide the indicator when now is before `displayStartHour` or after/equal `displayEndHour`.
3. Keep indicator visuals non-obstructive (thin line + small marker, no card text overlap).
4. Preserve existing schedule data flow, refresh gates, and lifecycle behavior.

### Scope defaults (from SpecFlow)

- **Primary scope:** Weekly calendar (`ScheduleWidget`) in the Classes page.
- **Date scope:** Render indicator only for today column.
- **Out-of-range behavior:** Strictly hide indicator (no pinned top/bottom affordance in this issue).
- **Update cadence:** Minute-boundary updates only (reuse existing now timer path).
- **Daily tab:** No behavior change in this issue unless required for consistency bug discovered during implementation.

### MVP pseudo-flow

File: `lib/schedule/ui/weeklyschedule/widgets/schedule_widget.dart`

```dart
// Pseudocode only
final nowInRange = isTodayVisible &&
    nowHourMinute >= displayStartHour &&
    nowHourMinute < displayEndHour;

if (nowInRange) {
  renderCurrentTimeOverlay(
    dayColumn: todayColumn,
    minuteOffset: mapNowToMinuteOffset(now, displayStartHour),
    style: material3NowIndicatorStyle(context),
  );
}
```

File: `lib/schedule/ui/weeklyschedule/widgets/schedule_current_time_indicator.dart`

```dart
// Pseudocode only
class ScheduleCurrentTimeIndicator extends StatelessWidget {
  // draws a 2dp line + small marker using theme tokens
  // ignores hit testing to avoid blocking lesson taps
}
```

## Technical Considerations

- **Layering:** indicator should remain visible against grid/cards while not covering lesson text content.
- **Bounds correctness:** enforce same hour-window math used by weekly schedule (`displayStartHour`, `displayEndHour`).
- **Theme consistency:** derive colors from theme/material roles, avoid hardcoded one-off colors.
- **Performance:** repaint only indicator layer on minute ticks; avoid unnecessary full-tree rebuilds.
- **Lifecycle safety:** no new timers beyond existing weekly now timer unless strictly required.
- **No data-model changes:** this is a UI rendering fix only; ERD changes are not applicable.

## SpecFlow Gaps + Defaults

- **Gap:** Should out-of-range now show a pinned affordance at edges?  
  **Default:** No; hide indicator fully to match issue requirement.
- **Gap:** Should indicator appear on non-today columns/pages?  
  **Default:** No; today column only.
- **Gap:** Should existing past shading stay, be reduced, or be removed?  
  **Default:** Keep subtle past shading, but make explicit now line the primary cue.
- **Gap:** Which token should drive indicator color?  
  **Default:** Use Material 3 role-based token (`colorScheme.primary`/contrast-safe variant) and verify contrast.
- **Gap:** Daily tab parity required now?  
  **Default:** No; track as follow-up if product requests consistent day-tab design.

## ✅ Acceptance Criteria

- [ ] Weekly calendar shows a clear current-time line/marker in the today column when now is within visible hours.
- [ ] Current-time indicator is hidden when now is before `displayStartHour` or after/equal `displayEndHour`.
- [ ] Indicator remains visible on empty grid areas (not only over lesson cards).
- [ ] Indicator does not obscure lesson text/content or block lesson tap interactions.
- [ ] Visual style follows Material 3 theme tokens and maintains non-text contrast >= 3:1 against the schedule background.
- [ ] Existing weekly cache-first load, refresh gating, and background refresh behavior remain unchanged.
- [ ] New regression tests for issue `#34` pass on CI and local Android verification.

## Success Metrics

- Repro from `#34` is no longer reproducible on light and dark themes.
- Manual Android checks confirm clear "now" visibility on schedule pages with sparse and dense lesson layouts.
- No observed regression in weekly swipe smoothness or minute update behavior.
- Added tests cover in-range, out-of-range, and overlap scenarios deterministically.

## Dependencies & Risks

- **Risk:** z-order conflicts with existing overlays/cards reduce visibility.  
  **Mitigation:** define explicit stack order and add widget tests for overlap scenes.
- **Risk:** contrast failures on dynamic/light/dark combinations.  
  **Mitigation:** choose role-based theme colors and assert contrast in tests/review.
- **Risk:** performance regression from repainting large calendar surfaces.  
  **Mitigation:** isolate indicator drawing and update once per minute only.
- **Risk:** accidental behavior changes in refresh/state paths while editing schedule UI files.  
  **Mitigation:** run related weekly viewmodel and lifecycle regression suites.

## 📋 Implementation Checklist (draft)

- [ ] Add regression-first widget tests in `test/schedule/ui/weeklyschedule/schedule_current_time_indicator_test.dart`.
- [ ] Add/replace weekly current-time overlay implementation in `lib/schedule/ui/weeklyschedule/widgets/schedule_widget.dart`.
- [ ] Introduce dedicated indicator widget/painter in `lib/schedule/ui/weeklyschedule/widgets/schedule_current_time_indicator.dart`.
- [ ] Add indicator style tokens/helper in `lib/common/ui/colors.dart` or a schedule-local theme helper.
- [ ] Verify no regressions in `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart` timer-driven now updates.
- [ ] Validate layering with existing overlay in `lib/schedule/ui/weeklyschedule/widgets/schedule_past_overlay.dart`.
- [ ] Record final fix in `docs/solutions/ui-bugs/` after implementation.

## Test Plan

### Automated (TDD-first)

- Add weekly indicator rendering tests:
  - `test/schedule/ui/weeklyschedule/schedule_current_time_indicator_test.dart`
  - cases: in-range visible, before-range hidden, after-range hidden, dense-overlap readability.
- Extend weekly layout/interaction tests where relevant:
  - `test/schedule/ui/weeklyschedule/schedule_widget_layout_profile_test.dart`
  - `test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`
- Keep refresh and gating regressions green:
  - `test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart`
  - `test/schedule/ui/viewmodels/schedule_update_request_gate_test.dart`

### Manual Android verification

- Open weekly calendar during visible hours and confirm clear current-time line visibility.
- Verify indicator visibility on empty slots and over dense lesson periods.
- Set/observe times outside visible hour window and confirm indicator is hidden.
- Validate dark/light theme readability and no blocked lesson taps.
- Leave app running across a minute boundary and confirm indicator updates without jank.

## AI-Era Implementation Notes

- Keep AI-assisted changes constrained to weekly schedule rendering and tests for issue `#34`.
- Use test-first workflow to prevent regressions in schedule lifecycle and refresh behavior.
- Require human review for final visual tuning (contrast, thickness, marker size) on real Android device.

## References & Research

### Related issue

- `#34`
- https://github.com/FarisZR/DualMate/issues/34

### Internal code references

- `lib/schedule/ui/weeklyschedule/widgets/schedule_widget.dart:124`
- `lib/schedule/ui/weeklyschedule/widgets/schedule_past_overlay.dart:62`
- `lib/schedule/ui/weeklyschedule/widgets/schedule_past_overlay.dart:80`
- `lib/schedule/ui/weeklyschedule/widgets/schedule_past_overlay.dart:108`
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:40`
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:242`
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:246`
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:543`
- `lib/common/ui/colors.dart:46`
- `lib/common/ui/colors.dart:101`
- `lib/common/ui/colors.dart:106`

### Institutional learnings

- `docs/rapla-cache-refresh-behavior.md:46`
- `docs/rapla-cache-refresh-behavior.md:59`
- `docs/solutions/ui-bugs/monday-lessons-missing-after-background-resume-20260210.md:27`
- `docs/solutions/ui-bugs/monday-lessons-missing-after-background-resume-20260210.md:29`
- `docs/solutions/ui-bugs/filters-dont-apply-calendar-without-interaction-20260209.md:34`
- `docs/solutions/ui-bugs/dark-surface-tint-and-status-bar-icons-20260202.md:27`
- `docs/solutions/ui-bugs/dark-surface-tint-and-status-bar-icons-20260202.md:47`

### External references

- https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html
- https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- https://docs.flutter.dev/ui/accessibility
- https://api.flutter.dev/flutter/rendering/CustomPainter-class.html
- https://docs.flutter.dev/perf/best-practices
- https://m3.material.io/styles/color/roles
