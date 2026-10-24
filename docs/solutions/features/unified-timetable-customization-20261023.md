---
module: Schedule
date: 2026-10-23
problem_type: feature
component: timetable_customization
root_cause: single_source_and_global_title_filters
resolution_type: architecture
severity: medium
tags: [schedule, material3, sources, notifications, migration]
---

# Combining timetable sources

The timetable toolbar opens Customize timetable. Source configuration and module
selection share one screen; Settings retains general display preferences.
Rapla and iCal can be mixed, Mannheim retains its searchable course directory,
and Dualis is available when adding or editing the primary timetable. Existing
Dualis configurations migrate with their account identity. Credentials stay in
memory while editing and are written to secure storage only on Save; previews
and active adapters use independent sessions.

SQLite schema 6 adds `sourceIdentity` to lessons plus `TimetableSources`,
`TimetableModuleSelections`, and `TimetableConfigurationState`. The first load
migrates the legacy source and hidden names in one transaction, preserving cached
lessons. The migration loop now starts after the previous database version so
non-idempotent migrations are not reapplied.

Module exceptions invert a source's default: the primary includes future modules,
while additions exclude them until selected. Choices are persisted by source and
title. Event copies, equality, cache matching and diffs retain source identity.

`CombinedScheduleSource` fetches sources concurrently and retains their namespaces.
A failed source fails the refresh as a whole, keeping the previous combined cache
instead of interpreting an unavailable source as deleted lessons. A configuration
revision is captured with the source snapshot and checked inside the cache write
transaction. This rejects stale foreground and background-isolate refreshes.

The schedule and notification diffs use the same current selection for both old
and new snapshots. Tomorrow's notification reads selected lessons. Class reminders
use source-specific rule indexes and filtered cache entries, cancel hidden alarms,
and remove obsolete sources, including cleanup after an interrupted source change.
The Android widget's SQL uses the same source/default/exception selection rules.
Dates use the combined source and invalidate their loaded state after edits.

The customization list uses lazy slivers. A 160-module tablet fixture mounts nine
module rows near the viewport rather than all 80 rows in the expanded class.
Parser isolates now live only for their request, including cancelled requests;
replacing sources and loading previews no longer retain idle workers. Combined
refresh cancellation fans out to a separate token for every source. Combining
events uses source-scoped record keys, avoiding a quadratic scan of all previous
lessons while preserving duplicate detection within each source.

The main cold-start suite defaults to one continuous `stress` journey, including
customization alongside Schedule, Canteen, Dates and Dualis. It uses two sources
and at least 160 modules, rapidly selects/expands/scrolls, saves and reopens in
three uninterrupted rounds. There are no per-section idle or frame-drain waits.
The focused `customization` target remains available for isolated diagnostics.

Device tests explicitly use Flutter's `fullyLive` frame policy. The inherited
test-driven policy made 100 ms `pumpAndSettle` steps visible in the preview and
provided too few animation frames for useful smoothness measurements. Ranking
runs exclude VM timeline collection and screenshot surface conversion. Separate
diagnostic tracing identifies expensive layout or graphics work without treating
the profiler's overhead as a release-build regression.

# Toolchain

Validated with Flutter 3.47.8 / Dart 3.13.7, AGP 9.4.1, Kotlin 2.4.21,
Gradle 9.8.2, Android SDK 37.2 and Build Tools 37.0.0. CI pins the same Flutter
version. Direct packages are upgraded to current stable versions. The latest
secure-storage plugin supports Android API 24; the app retains its Android 7 minimum.
The older `device_calendar` dependency still constrains timezone to 0.9; the
timezone override uses 0.11.2 alongside notifications 22.3.2. Calendar code compiles
against the unchanged TZDateTime interface; local calendar export remains gated
by its existing feature flag.

Run Flutter builds and tests sequentially because both regenerate the Android
plugin registrant. Plugins that still apply KGP produce Flutter's existing
built-in-Kotlin migration warning; current builds remain supported.

Regression evidence is recorded in the pull request and the timetable screenshots
under `screenshots/timetable-customization/`. The four existing canteen bounds
test failures also reproduce on base commit 602cb2a with Flutter 3.44.4.
