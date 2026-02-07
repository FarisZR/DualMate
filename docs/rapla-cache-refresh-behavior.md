# Rapla + Schedule cache and refresh behavior

This document describes how the Rapla events page and the weekly schedule view
use caching, lazy loading, and background refresh.

## Rapla events (Date Management)

### Cache source
- Events are built from the shared schedule cache (ScheduleProvider-backed).
- Important events are derived from schedule entries and merged/deduped in the
  RaplaImportantEventsProvider.

### Initial load
- The first window is 3 months starting today.
- Cached windows (up to the last stored window end) are loaded immediately so
  previously seen events appear instantly.
- After cached windows load, the first window fetch happens; results update as
  they arrive.

### Lazy loading
- Pages load in 3-month windows as the user scrolls.
- Loading is throttled with a cooldown to avoid repeated requests.
- If a page loads no new non-duplicate events, pagination stops and the UI shows
  "No more events".

### Scraping optimizations
- Cooldown between Rapla window fetches to prevent rapid repeat requests.
- Stop requesting further windows when a fetch yields no new events.
- Clamp total fetch range to the next 3 years.
- If the last non-holiday event ends at date X, stop at X + 365 days.

### Refresh behavior
- Each window has its own freshness gate; stale windows refresh in the
  background after cached results are displayed.
- The furthest loaded window end is persisted in preferences so cached windows
  can be restored on next open.

### Fetch limits
- Hard limit: do not fetch beyond 3 years from today.
- Additional limit: if the last non-holiday event ends at date X, do not fetch
  beyond X + 365 days (even if the 3-year limit is further out).

## Weekly schedule (Classes)

### Cache source
- Weekly schedule reads cached entries for the visible week first, then updates.

### Initial load
- If the cached week is empty and the schedule source can query, a network fetch
  is forced to avoid showing an empty schedule as "fresh".

### Cache management
- The schedule cache can be invalidated manually (e.g., when schedule filters change) via `scheduleProvider.invalidateScheduleCache()`.
- This ensures that hidden classes or updated source settings take effect immediately on the next navigation or refresh.

### Refresh behavior
- Each viewed week has a per-window freshness gate to avoid stale data.
- The next 14 days are refreshed regularly (periodic background update) so the widget and schedule stay current.
- **Cache-First Transition**: When opening a week, cached data is applied instantly. If the week is stale (15–30 min), a background fetch is unawaited to update the view without blocking navigation.


## Related files
- lib/date_management/ui/viewmodels/date_management_view_model.dart
- lib/date_management/business/rapla_important_events_provider.dart
- lib/date_management/ui/date_management_page.dart
- lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart
- lib/schedule/business/schedule_provider.dart
- lib/schedule/background/background_schedule_update.dart
