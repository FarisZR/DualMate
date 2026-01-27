---
title: fix: android widget resize recalculation and canteen deduplication
type: fix
date: 2026-01-27
---

# fix: android widget resize recalculation and canteen deduplication

## Overview
Widgets on Android fail to refresh visible rows after resize because AppWidget option changes are not handled. The canteen widget occasionally shows the first item twice, likely due to duplicate source rows lacking deduplication. This plan restores resize-driven recompute while keeping full data loaded and trims by size, and adds safe deduplication for canteen rows.

## Problem Statement / Motivation
- Resize does not trigger `notifyAppWidgetViewDataChanged`, so `MultiDayViewsFactory` never recalculates visible rows for the new height; extra space stays empty until a later data refresh.
- Canteen widget sometimes renders the first item twice before the second, pointing to duplicate rows in the provider query with no deduplication.
- Android widgets are a core surface; inconsistent resize and duplicated rows degrade trust and clarity.

## Proposed Solution
- Add `onAppWidgetOptionsChanged` to relevant providers to call `notifyAppWidgetViewDataChanged` for their list view IDs per `appWidgetId`, ensuring height recalculation and visibility trimming rerun on resize.
- Keep loading the full 7-day data window; trim rows based on recalculated visible count so content is always loaded but hidden when space is limited.
- Introduce deterministic deduplication for canteen rows before rendering (assume key: date + category + normalized name + price), preserving current sort order.

## Technical Considerations
- **Scope**: Android only (per AGENTS.md); impacts `CanteenTodayWidget`, `ScheduleTodayWidget`, optionally `ScheduleNowWidget` if reuse fits.
- **Height calc**: `MultiDayViewsFactory` already reads `OPTION_APPWIDGET_MIN_HEIGHT/MAX_HEIGHT`; resize hook just needs to trigger data change. Ensure DP conversion consistent with existing row-height logic.
- **Performance**: Resizes may fire repeatedly; rely on system throttling but keep work minimal (notify+rebind). Avoid blocking main thread.
- **Ordering**: Current ORDER BY `date ASC, category ASC, name ASC` should remain; dedup must not reorder items.
- **Duplicates**: If upstream inserts true duplicates, dedup removes them; identical legitimate items (same fields) will collapse—acceptable unless product objects.
- **Localization**: Messages (if any) must support en/de; sorting currently lexicographic.
- **Concurrency**: Multiple widget instances should use their own `appWidgetId` in notifications; factories must remain stateless per instance.
- **Fallbacks**: If resize triggers while offline, reuse last data or show existing empty/error state (no crash).

## Acceptance Criteria
- [x] Resizing any relevant widget triggers a data refresh and recomputation of visible rows for that widget instance; additional rows appear when space increases and are trimmed when it decreases without waiting for periodic updates.
- [x] Full data window loads before trimming; content is hidden only by size limits, not by query. (Updated window to 14 days for schedule.)
- [x] Canteen widget no longer displays duplicate first item; dedup removes repeated rows with identical date/category/name/price while preserving order.
- [x] Multiple widget instances at different sizes refresh independently on resize.
- [x] Offline/empty states remain stable after resize; no crashes or stale layout artifacts.
- [x] Behavior verified on portrait and landscape with at least two height configurations.

## Success Metrics
- Manual QA: resize → visible row count changes immediately without lag.
- Bug repro baseline (duplicate first item) no longer reproducible after fix.
- No new ANRs or crashes in widget providers/factories during resize stress.

## Dependencies & Risks
- Risk of over-notifying on rapid resize; mitigated by lightweight handler.
- Dedup key assumption may hide legitimate identical meals; confirm data model expectations.
- If `ScheduleNowWidget` shares patterns, ensure optional inclusion does not introduce regression.

## Implementation Steps (draft)
- [x] Add `onAppWidgetOptionsChanged` overrides in `android/app/src/main/kotlin/com/fariszr/dualmate/widget/canteen/CanteenTodayWidget.kt` and `.../widget/today/ScheduleTodayWidget.kt` (and `.../widget/now/ScheduleNowWidget.kt` if applicable) to call `AppWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, listViewId)`.
- [x] Ensure `MultiDayViewsFactory` uses current options in `getWidgetHeightDp`; no logic change expected.
- [x] Implement dedup in `android/app/src/main/kotlin/com/fariszr/dualmate/widget/canteen/CanteenEntryViewsFactory.kt` before grouping rows (key: date, category, normalized name, price) or add DISTINCT in `CanteenProvider` if safe; keep stable ordering.
- [x] Add/adjust tests mirroring `MultiDayWidgetHelperTest` for resize recalculation and a canteen dedup unit test.

## References & Research
- Widget helpers: `android/app/src/main/kotlin/com/fariszr/dualmate/widget/MultiDayViewsFactory.kt`, `.../MultiDayWidgetHelper.kt`
- Providers: `.../widget/canteen/CanteenTodayWidget.kt`, `.../widget/canteen/CanteenEntryViewsFactory.kt`, `.../database/CanteenProvider.kt`, `.../widget/today/ScheduleTodayWidget.kt`, `.../widget/now/ScheduleNowWidget.kt`
- Docs: `docs/multi-day-widgets.md`; `docs/solutions/integration-issues/canteen-widget-crashes-and-locking-Canteen-20260124.md`; `docs/solutions/integration-issues/widget-tap-not-navigating-android-widgets-20260122.md`; perf mention in `docs/plans/2026-01-26-fix-frame-drops-main-thread-load-plan.md`
- Spec-flow insights: need resize hook, clarify dedup key, handle multiple instances and offline states.

## Open Questions (assumptions noted)
- Dedup key: proceed with date + category + normalized name + price? (Assumed yes.)
- Should dedup live only in factory or also via SQL DISTINCT in `CanteenProvider`? (Assumed factory-level to preserve ordering.)
- Any debounce for rapid resize events? (Assumed no, rely on system.)
- Confirm current ORDER BY is desired (date, category, name) and today-first behavior. (Assumed yes.)
