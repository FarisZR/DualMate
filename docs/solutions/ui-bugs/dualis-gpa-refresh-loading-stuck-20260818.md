---
module: Dualis UI
date: 2026-08-18
problem_type: ui_bug
component: frontend_flutter
symptoms:
  - "Pull-to-refresh leaves the Dualis GPA and credits summary loading"
  - "Module results can finish and remain visible while the overview is stuck"
root_cause: study_grades_failure_skipped_the_loading_state_notification
resolution_type: code_fix
severity: medium
tags: [dualis, grades, gpa, refresh, loading, sentry]
---

# Dualis GPA summary stuck after pull-to-refresh

## Problem

When the study-grades request failed during a Dualis refresh, the module branch
could still finish successfully while the GPA and credits summary kept showing
its loading placeholder. The refresh failure was represented by Sentry issues
`129756006` and `140729034`.

## Root cause

`StudyGradesViewModel.loadStudyGrades` reset `isLoadingStudyGrades` in its
`finally` block, but the unexpected exception was rethrown before the property
change notifications after that block ran. The in-memory flag was therefore
false while the last rendered UI state still showed loading.

## Fix

- Catch unexpected study-grades failures so a pull-to-refresh completes.
- Continue reporting unexpected failures through the privacy-safe diagnostics
  path; expected connectivity and cancellation failures remain suppressed by
  the existing diagnostics filter.
- Clear and notify the GPA loading state from `finally`, so cleanup happens on
  success, cancellation, and failure.
- Keep the last successfully loaded GPA and credits values when refreshing
  fails.
- Do not advance the last-successful-refresh timestamp when the GPA branch
  fails, allowing the stale-refresh policy to retry it.

## Regression coverage

- A widget test starts the GPA load, verifies the loading placeholder, fails
  the service request, and verifies that the previous summary is restored.
- A view-model test exercises the complete forced-refresh path and verifies
  that the GPA failure does not stop the module and semester-name branches or
  leave the GPA loading flag set.
