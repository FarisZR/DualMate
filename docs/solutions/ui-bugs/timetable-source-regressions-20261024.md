---
module: Schedule customization
date: 2026-10-24
problem_type: ui_bug
component: timetable_sources
root_cause: source_picker_excluded_new_dualis_configurations
resolution_type: code_fix
severity: high
tags: [dualis, schedule, migration, reminders, dates, regression]
---

# Restoring Dualis and startup integration

The unified source picker exposed Dualis only for existing Dualis configurations,
and its account field was read-only. Students could no longer choose Dualis for
their primary timetable. The picker now permits Dualis when adding the first
timetable or editing the primary class, with validated username/password fields
and prefilled saved credentials. Additional sources retain independent module
choices without introducing multiple Dualis accounts.

Credentials remain in memory until Save. Preview adapters have their own sessions
and cannot replace the active account. A failed preview keeps the previous source;
a failed configuration save restores the previous secure-storage credentials.
Passwords are never included in timetable rows or source identities.

A configured Dualis adapter is queryable before its first login, so it can
participate in the combined source after a cold start. Failed login is reported
as a query failure rather than an empty successful refresh.

PR review also exposed startup ordering issues: reminder initialization now loads
persisted source identities before deleting obsolete rules, and Dates reads the
saved timetable snapshot before source setup. Dates compares configuration
revision and identities before invalidating a page, preserving events during
unchanged setup callbacks and reloading selections even while offline.

Source setup now reports invalid child adapters as invalid configuration. An
explicit performance-fixture override survives setup and Save callbacks, avoiding
accidental network requests before the harness can re-pin it. The script invokes
the canonical harness/driver directly; the old aggressive entry points remain
delegating compatibility wrappers with the same workload.

The installed `flutter_secure_storage` 11.2.0 Android manifest/build configuration
requires API 24, so the app retains API 24 support. The earlier API 26 requirement
in the feature documentation was incorrect.

Regression checks cover the primary/empty/additional picker paths, secure-storage
commit/discard/failure behavior, password-only changes, cold Dualis queries,
reminder startup before source setup, unchanged Dates callbacks, offline selection
changes, invalid child sources and preserving the performance fixture during Save.
The connected tablet integration test uses the public review account and captures
the restored source form. The cyclomatic-complexity check uses the merged v2
configuration (threshold 20), with source validation extracted from the dialog
builder instead of suppressing the metric.

Validation on this revision: Flutter analysis and the new complexity command both
pass; 375 focused schedule/date/Sentry tests pass. The full suite finishes with
638 passing tests and the same four pre-existing canteen bounds failures. The
profile-mode Dualis tablet integration test passes. The previous complete stress
run remains the performance evidence; these fixes do not change the rendered
module list or its scrolling behavior.
