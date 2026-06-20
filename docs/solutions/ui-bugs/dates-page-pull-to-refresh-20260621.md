---
module: Date Management
date: 2026-06-21
problem_type: feature
component: Dates page UI
root_cause: missing_interaction
resolution_type: code_addition
severity: low
tags: [rapla, dates, refresh, ui]
---

# Pull-to-refresh on the Dates page

## Problem

The Dates page had no way to manually trigger a refresh of its content.
Users had to navigate away or wait for background/lifecycle refreshes to
pick up new Rapla important events or DHmine date entries.

## Solution

Wrapped the Dates page data views in a `RefreshIndicator` that calls
`DateManagementViewModel.updateDates()`.

- `lib/date_management/ui/date_management_page.dart` `_buildContent`:
  - Rapla mode (important events list): wrapped in `RefreshIndicator`; the
    underlying `ListView`/`ListView.separated` got
    `AlwaysScrollableScrollPhysics` so the indicator arms even when the list
    content is shorter than the viewport.
  - DHmine mode (DataTable): wrapped in `RefreshIndicator` with an outer
    `SingleChildScrollView` (`AlwaysScrollableScrollPhysics`) so the
    non-scrollable DataTable can overscroll.
  - The empty state and invalid-Rapla-URL banner are setup prompts and are
    intentionally left without `RefreshIndicator` (they contain a
    `LayoutBuilder`-based placeholder that is incompatible with intrinsic
    layout, and refreshing a setup prompt is not meaningful).

## Notes

- `updateDates()` already cancels in-flight updates via `_updateMutex`, so it
  is safe to call from the indicator.
- During a pull-to-refresh the existing `LinearProgressIndicator` header may
  also show because `updateDates` notifies `isLoading`; the
  `RefreshIndicator` spinner is the primary affordance.
- Widget tests in `test/date_management/ui/date_management_page_test.dart`
  verify that pulling triggers `updateDates()` in both Rapla and DHmine modes.
