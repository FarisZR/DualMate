---
module: Dualis UI
date: 2026-05-19
problem_type: ui_bug
component: frontend_flutter
symptoms:
  - "Dualis asks the user to log in again after reopening the app"
  - "There is no manual pull-to-refresh path on the Dualis pages"
  - "Returning to Dualis after a long time does not automatically refresh stale data"
root_cause: dualis_view_model_only_supported_explicit_login_and_never_revalidated_on_page_visibility
resolution_type: code_fix
severity: medium
tags: [dualis, login, session, refresh, cache, flutter, android]
---

# Troubleshooting: Dualis session persistence and refresh

## Problem
Dualis only stayed usable for the current in-memory session. After reopening the app, the page returned to the login form even when credentials were already stored. The logged-in views also lacked a manual refresh affordance.

## Root Cause
The Dualis view model supported explicit login only. It never attempted to restore a stored session when the page became visible again, and it had no persisted freshness timestamp to decide when stale data should be reloaded automatically.

## Solution
- Updated `StudyGradesViewModel` to:
  - start in an initializing state so Dualis does not render the logged-out UI before the first saved-credential check completes
  - restore the Dualis session from saved credentials when the Dualis section becomes visible
  - refresh stale Dualis data automatically when reopening the section after a long gap
  - expose `refreshData(force: true)` so the UI can trigger a full cache-busting reload
  - track the last successful Dualis refresh in preferences
- Updated `DualisPage` to:
  - observe section visibility inside the main `IndexedStack`
  - trigger the stale-session refresh flow on first show and on app resume while Dualis is active
  - show a loading state while the session is being restored
- Added pull-to-refresh to:
  - `StudyOverviewPage`
  - `ExamResultsPage`
- Extended the Dualis service contract with `clearCache()` so forced refreshes bypass cached grade/module data.

## Test Coverage
- `login falls back to LoginFailed on unexpected service errors`
- `loadAllModules keeps loading=true for the newest in-flight request`
- `restores the Dualis session from saved credentials on page open`
- `does not show login page before restoring saved session`
- `refreshData(force: true) clears cached Dualis data before reloading`
- existing Dualis loading animation widget tests

## Commands run
```bash
flutter test test/dualis/ui/viewmodels/study_grades_view_model_test.dart test/dualis/ui/study_overview_loading_animation_test.dart test/dualis/ui/dualis_page_session_restore_test.dart
flutter analyze lib/dualis lib/common/data/preferences/preferences_provider.dart test/dualis/ui/viewmodels/study_grades_view_model_test.dart test/dualis/ui/study_overview_loading_animation_test.dart
```
