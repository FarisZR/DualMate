---
title: fix: canteen swipe bounds and overscroll indicator
type: fix
date: 2026-02-10
---

# fix: canteen swipe bounds and overscroll indicator

## Overview
🐛 The canteen page currently allows horizontal paging across an effectively unbounded weekday timeline, which exposes many empty days. Because the canteen source removes past menus and some future days/weeks also have no meals, users repeatedly land on empty states that are not actionable.

This plan constrains navigation to days with actual meal content and adds a visible overscroll affordance at both boundaries (past and future) using `StretchingOverscrollIndicator`.

## Problem Statement / Motivation
- `PageView.builder` in `lib/canteen/ui/canteen_page.dart:131` is unbounded and always resolves a date (`_dateForPage` at `lib/canteen/ui/canteen_page.dart:187`), so users can swipe to dates with no data.
- The provider intentionally builds five weekday menu buckets even when meal lists are empty (`lib/canteen/business/canteen_provider.dart:124`), which is valid for data normalization but noisy for page navigation.
- Empty-state rendering in `_CanteenDayView` (`lib/canteen/ui/canteen_page.dart:312`) is currently used both for real errors and for navigation into known-empty dates, conflating UX states.
- GitHub issue reference: https://github.com/FarisZR/DualMate/issues/18

## Research Summary
### Internal code references
- Canteen page paging and date mapping: `lib/canteen/ui/canteen_page.dart:131`, `lib/canteen/ui/canteen_page.dart:187`, `lib/canteen/ui/canteen_page.dart:209`
- Empty day fallback rendering: `lib/canteen/ui/canteen_page.dart:312`
- Week cache/load state + per-day meals access: `lib/canteen/ui/viewmodels/canteen_view_model.dart:60`, `lib/canteen/ui/viewmodels/canteen_view_model.dart:103`
- Provider normalization that emits weekday entries regardless of meal count: `lib/canteen/business/canteen_provider.dart:124`

### Institutional learnings (`docs/solutions/`)
- Defer initial state changes and keep post-frame loading patterns stable in canteen viewmodel (`docs/solutions/integration-issues/canteen-widget-crashes-and-locking-Canteen-20260124.md`).
- Keep cache-first UX and avoid regressing loading responsiveness in canteen flows (`docs/solutions/performance-issues/absolute-startup-schedule-optimization-20260207.md`).
- Prior canteen fixes emphasize deterministic behavior and edge-case handling for date windows (`docs/solutions/ui-bugs/widget-resize-and-canteen-duplication-20260127.md`).

### External research decision
- Skipped for this issue. The request targets existing in-repo Flutter code paths and directly names the official API class to use (`StretchingOverscrollIndicator`).

## SpecFlow Analysis (Flows + Gaps)
### Primary user flow
1. User opens canteen page.
2. App resolves visible days with actual meals.
3. User can swipe only within this finite content range.
4. Swiping beyond left/right boundary does not change day and shows overscroll feedback.

### Edge cases to cover
- Today has no meals but a future day does: initial page should select the first day with meals.
- Loaded range has no meals at all (e.g., source empty week): show a stable non-paged empty/error screen instead of infinite empty swiping.
- Filter hides all meals for a visible date: keep navigation bounds based on raw menu availability, not filter result, so user can still move between real menu days.
- Widget deep-link target day is outside current visible bounds: clamp to nearest valid visible day.
- Async loading updates bounds while user is on page: preserve current day when still valid; otherwise snap to nearest valid day once.

## Proposed Solution
### 1) Build finite, content-backed navigation bounds
- Introduce visible day computation in `lib/canteen/ui/viewmodels/canteen_view_model.dart`:
  - derive sorted weekday dates where menu has at least one raw meal (before filter), from loaded weeks.
  - expose helpers for first/last visible day and nearest visible day.
- Keep existing cache-first + refresh behavior unchanged.

### 2) Replace unbounded date index mapping in page layer
- Refactor `lib/canteen/ui/canteen_page.dart` to drive `PageView` from a finite `List<DateTime> visibleDays` instead of `_basePage` arithmetic.
- Maintain date title and "Back to today" behavior, but update logic:
  - "today" action should jump to today if visible, else nearest visible day.
  - widget payload navigation should clamp to visible bounds.

### 3) Add boundary overscroll affordance
- Wrap the horizontal page list with `StretchingOverscrollIndicator` in `lib/canteen/ui/canteen_page.dart` so attempts to move before first or after last visible day show clear stretch feedback.
- Keep platform-appropriate physics and ensure indicator appears at both start/end boundaries.

### 4) Preserve meaningful empty/error states
- Keep `_CanteenDayView` empty UI for genuine "no content loaded at all" and fetch errors.
- Remove empty-day navigation as a normal state by preventing those pages from being created.

## Technical Considerations
- Navigation bounds must be computed from unfiltered meals; otherwise changing filter would unexpectedly shrink/expand page count.
- Bounds are only as good as loaded data; when additional weeks load, page list may extend and should update without jarring jumps.
- Date normalization remains weekday-only; no weekend pages should be introduced.
- Ensure no regression in telemetry hooks (`canteen.entry`, `canteen.pageChanged`) in `lib/canteen/ui/canteen_page.dart:37` and `lib/canteen/ui/canteen_page.dart:138`.

## Acceptance Criteria
- [ ] Users cannot navigate to past/future canteen days that have no menu content.
- [ ] Swiping before the first visible content day shows overscroll stretch feedback and does not navigate further back.
- [ ] Swiping after the last visible content day shows overscroll stretch feedback and does not navigate further forward.
- [ ] If the current week has no meals but later loaded days do, the page opens at the first available day with meals.
- [ ] If no visible meal day exists in loaded data, the page shows a single stable empty/error state (no infinite horizontal swipe).
- [ ] Widget payload day targeting still works and clamps to nearest visible day when exact day is unavailable.
- [ ] Refresh and loading behavior remains functional and free of `notify`-during-build issues.

## Implementation Plan
1. `lib/canteen/ui/viewmodels/canteen_view_model.dart`
- Add methods for visible day extraction from `_weeklyMenus` (raw meals, sorted unique weekdays).
- Add helpers: `firstVisibleDay`, `lastVisibleDay`, `nearestVisibleDay`.

2. `lib/canteen/ui/canteen_page.dart`
- Replace `_basePage`/`_dateForPage` driven infinite mapping with finite visible-day indexing.
- Keep header date + FAB behavior consistent with new indexing.
- Clamp widget payload target to visible range.
- Wrap page content with `StretchingOverscrollIndicator`.

3. `test/canteen/ui/canteen_page_bounds_test.dart` (new)
- Add widget tests for: no past empty-day navigation, no beyond-last-day navigation, overscroll indicator presence, nearest-day clamp.

4. `test/canteen/ui/viewmodels/canteen_visible_days_test.dart` (new)
- Add unit tests for visible day derivation and nearest-day selection.

## Success Metrics
- Manual QA on Android: no reproducible path to swipe into empty historical days on canteen page.
- Manual QA on Android: visible stretch indicator appears when swiping beyond first/last content day.
- Automated tests cover bound calculation and clamping logic for deterministic regressions.

## Dependencies & Risks
- Risk: bounds may change while loading next week and cause page jumps.
  - Mitigation: preserve current selected day when still in visible list; otherwise clamp once.
- Risk: filter interaction could accidentally affect page bounds.
  - Mitigation: derive bounds from raw meals, apply filters only inside day content.
- Risk: overscroll visuals vary by platform/theme.
  - Mitigation: verify behavior on actual Android device via debugger run (`flutter run -d <DEVICE_ID>`).

## Verification Plan
- Automated:
  - `flutter test test/canteen/ui/viewmodels/canteen_visible_days_test.dart`
  - `flutter test test/canteen/ui/canteen_page_bounds_test.dart`
- Manual (Android device):
  - Run `flutter run -d <DEVICE_ID>`.
  - Swipe left at first visible day and right at last visible day; confirm stretch indicator and no day change.
  - Validate startup on weeks with sparse meals and widget deep-link day navigation.

## References & Related Work
- Issue: https://github.com/FarisZR/DualMate/issues/18
- Flutter API: https://api.flutter.dev/flutter/widgets/StretchingOverscrollIndicator-class.html
- Canteen page: `lib/canteen/ui/canteen_page.dart:131`
- Canteen viewmodel: `lib/canteen/ui/viewmodels/canteen_view_model.dart:60`
- Canteen provider normalization: `lib/canteen/business/canteen_provider.dart:124`
- Related prior plan: `docs/plans/2026-01-27-fix-android-widget-resize-and-canteen-duplication-plan.md`
