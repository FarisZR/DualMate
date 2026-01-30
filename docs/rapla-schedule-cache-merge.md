# Rapla events share the schedule cache

This document explains how the Date Management (Rapla events) view now reuses
the same schedule cache as the main schedule page.

## Goal

Keep a single source of truth for Rapla data so both the schedule and events
pages use identical cached entries, freshness logic, and update paths.

## What changed

- The Rapla events pipeline no longer uses the old Preferences JSON cache.
- Events are derived from the schedule cache (ScheduleProvider-backed).
- Rapla events refresh uses the same schedule update path as the weekly view.
- Cached windows are restored on open and refreshed in the background.

## Data flow

1. Date Management requests a Rapla window.
2. ScheduleProvider reads cached ScheduleEntry rows for the window.
3. RaplaImportantEventsProvider filters/merges ScheduleEntries into
   ImportantEvents.
4. If the window is stale, ScheduleProvider fetches updates and the cache is
   refreshed, then the events list is rebuilt from the updated cache.

## Why this matters

- Consistent data between schedule and events.
- Reduced duplicate fetching and parsing work.
- Single freshness gate strategy with shared schedule infrastructure.

## Related files

- lib/date_management/business/rapla_important_events_provider.dart
- lib/date_management/ui/viewmodels/date_management_view_model.dart
- lib/schedule/business/schedule_provider.dart
- lib/schedule/data/schedule_entry_repository.dart
- lib/schedule/data/schedule_query_information_repository.dart
