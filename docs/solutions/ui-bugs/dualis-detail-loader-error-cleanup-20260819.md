---
module: Dualis UI
date: 2026-08-19
problem_type: ui_bug
component: frontend_flutter
symptoms:
  - "Dualis detail placeholders can remain visible after an unexpected loader failure"
  - "Loading flags are false internally while listeners retain stale loading state"
root_cause: detail_loader_failure_skipped_the_loading_state_notification
resolution_type: code_fix
severity: medium
tags: [dualis, modules, semesters, loading, refresh, sentry]
---

# Dualis detail loaders remain rendered as loading after failures

## Problem

The module overview, semester selector, and current-semester result loaders
reset their loading flags in `finally`, but notified their UI listeners after
that block. An unexpected parsing or service exception left the model clean
internally while the last rendered state could remain a loading placeholder.

## Fix

`loadAllModules`, `loadSemesterByName`, and
`loadSemesterNamesForCurrentSelection` now notify both their content property
and loading property from the existing epoch-guarded `finally` blocks. This
matches `loadStudyGrades`: success, cancellation, and failure all publish the
cleanup state, while unexpected failures continue propagating to the app-level
diagnostics and Sentry path.

No other Dualis detail loader had notifications after its cleanup block.

## Regression coverage

Each affected loader has a test that injects an unexpected service failure and
verifies that:

- the error still propagates;
- the loading listener observes `true` followed by `false`; and
- the related content listener receives the guaranteed cleanup notification.
