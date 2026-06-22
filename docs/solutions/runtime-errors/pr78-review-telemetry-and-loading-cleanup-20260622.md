---
module: Performance diagnostics
date: 2026-06-22
problem_type: runtime_error
component: telemetry
symptoms:
  - "Loading state could remain set after stale canteen requests exited early"
  - "Telemetry result labels could be overwritten by coarse success status"
  - "Cache-open failures could escape from unawaited schedule navigation flows"
root_cause: async_cleanup_and_status_key_collision
resolution_type: code_fix
severity: medium
tags: [performance, telemetry, canteen, schedule, dualis]
---

# Troubleshooting: PR 78 Review Fixes for Async Cleanup and Telemetry Status

## Problem
Review feedback on PR 78 identified a few small runtime diagnostics issues:
stale canteen week loads could bypass loading-state cleanup, telemetry payloads
used the same `status` key as coarse task completion, and cached schedule open
failures could propagate after already being reported.

## Cause
- Canteen week loading removed `_loadingWeeks` only at the normal end of the
  task block.
- `measureTask` writes the coarse completion status after the action returns,
  so action-level `status` payloads were overwritten.
- `_openWeekFromCache` reported cache-open failures and then rethrew them.

## Fix
- Wrap canteen week loading in `try/finally` and perform loading cleanup from
  the `finally` block.
- Keep Dualis login outcome under `result` instead of `status`.
- Let schedule fetch and parse provide their coarse success status through
  `measureTask`, including result-aware fetch statuses for empty schedules.
- Stop rethrowing cache-open failures after logging and reporting them.

## Related files
- `lib/canteen/ui/viewmodels/canteen_view_model.dart`
- `lib/common/logging/performance_telemetry.dart`
- `lib/dualis/ui/viewmodels/study_grades_view_model.dart`
- `lib/schedule/business/schedule_provider.dart`
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart`
