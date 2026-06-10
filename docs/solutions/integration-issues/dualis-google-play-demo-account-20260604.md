---
module: Dualis Integration
date: 2026-06-04
problem_type: integration_issue
component: frontend_flutter
symptoms:
  - "Google Play review needs access to the restricted Dualis integration"
root_cause: review_build_had_no_documented_reusable_dualis_demo_credentials
resolution_type: code_fix
severity: medium
tags: [dualis, google-play, review, demo-account, mock-data]
---

# Troubleshooting: Dualis Google Play demo account

## Problem
Google Play reviewers need reusable credentials to inspect the Dualis section,
but a real DHBW Dualis account should not be shared for review.

## Solution
The Dualis scraper is wrapped by `FakeAccountDualisScraperDecorator`. In normal
app builds, the following credentials select a local mock Dualis scraper instead
of the real Dualis network scraper:

- Username: `review@dualmate.app`
- Password: `DualisDemo2026!`

These credentials are intended for Play Console App Access instructions only.
They load deterministic local data and do not require a real DHBW/Dualis
account.

## Play Console text
```text
The Dualis section requires credentials.

Open the app, go to Dualis, and enter:
Username: review@dualmate.app
Password: DualisDemo2026!

These credentials load local demo Dualis data for review. No external DHBW/Dualis account is required.
```

## Test Coverage
- Demo credentials log in and route Dualis reads to fake data.
- Demo credential matching tolerates leading and trailing whitespace.
- Non-demo credentials stay on the original Dualis scraper.
- Stored demo credentials work with previous-credentials login.
- Logout clears the fake login state.

## Commands run
```bash
flutter test test/dualis/service/fake_account_dualis_scraper_decorator_test.dart test/dualis/ui/viewmodels/study_grades_view_model_test.dart test/dualis/ui/dualis_page_session_restore_test.dart test/dualis/ui/study_overview_loading_animation_test.dart
flutter analyze lib/dualis lib/common/appstart/service_injector.dart test/dualis
```
