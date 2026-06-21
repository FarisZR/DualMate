---
module: Schedule UI
date: 2026-06-21
problem_type: ui_bug
component: weekly_schedule
symptoms:
  - "Unloaded weeks with empty cache looked like genuinely empty weeks"
  - "Visible-week first load waited for the slow stale-check debounce"
root_cause: state_modeling
resolution_type: code_fix
severity: medium
tags: [schedule, weekly, cache, refresh, pager, metadata]
---

# Troubleshooting: Unknown Empty Weeks Stay Blank Until Manual Refresh

## Problem
After the schedule pager was optimized to avoid refresh work during active
swipes, newly visited weeks could render from an empty cache and then wait for
the normal visible-week stale-check debounce. Users saw a blank week long
enough to read it as genuinely empty.

## Cause
The weekly view model treated "empty cache" and "already fetched but empty" too
similarly. It only had in-memory freshness gates, so an empty week with no
entries could be unknown after app restart or after browsing into a new window.

## Fix
- Keep cache-first week opening.
- Track fetched windows separately from stale/fresh timing.
- Use persisted schedule query metadata to recognize known empty weeks.
- When the committed visible week has an empty cache and no query metadata,
  schedule a short request-aware forced refresh instead of waiting for the
  long stale-check debounce.
- Keep the slow debounce for known weeks so browsing does not start network
  refreshes for intermediate pages.

## Guardrails
- Scheduled initial refreshes verify the view model is mounted, the original
  open request is still current, the target week is still visible, the schedule
  source is queryable, and the week still lacks query metadata.
- Background refreshes still avoid mutating visible state when requested for
  widget/range maintenance.
- Adjacent prefetch remains cache-only.

## Related files
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart`
- `lib/schedule/business/schedule_provider.dart`
- `test/schedule/ui/viewmodels/weekly_schedule_view_model_pager_test.dart`
- `test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`
