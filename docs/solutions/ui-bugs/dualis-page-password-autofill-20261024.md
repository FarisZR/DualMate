---
module: Dualis UI
date: 2026-10-24
problem_type: ui_bug
component: frontend_flutter
symptoms:
  - "Password autofill works during onboarding but not on the later Dualis login page"
root_cause: missing_autofill_metadata
resolution_type: code_fix
severity: medium
tags: [dualis, login, autofill, password-manager, android]
---

# Dualis page password autofill

## Cause

Issue [#145](https://github.com/FarisZR/DualMate/issues/145) affects students
who skip Dualis setup during onboarding and log in later. The main Dualis page
uses `LoginForm`, rather than the shared `LoginCredentialsWidget` used by
onboarding. The earlier autofill fix covered the shared widget, leaving the
main page's username and password fields without autofill metadata or grouping.

## Fix

Group the main login fields in an `AutofillGroup` and give them the same username,
password, and best-effort Dualis domain hints as onboarding. Commit the autofill
context after successful authentication, independently of the app's existing
"Save login data" checkbox. That checkbox still controls the app's own credential
storage. Cancel the context when the form is removed without a successful login,
so leaving an unsubmitted or failed attempt does not request credential saving.

The fields' appearance and existing loading/error behavior remain unchanged.

## Validation

`test/dualis/ui/login_form_autofill_test.dart` covers the platform text-input
configuration, delivery of both credentials through an Android autofill message,
submission of those credentials, successful and failed authentication with both
credential-storage preferences, and cancellation when leaving unsubmitted or
failed forms. The new tests reproduced the missing grouping/save lifecycle
before the fix.

Using Flutter 3.47.8 / Dart 3.13.7:

- Dualis, shared credential-widget, and onboarding suites: 66 tests passed.
- `flutter analyze` and the CI complexity check: no issues.
- Full `flutter test`: 636 passed, four failed. The same four canteen paging
  failures reproduce with `origin/v2` production code and existing tests and are
  already recorded in the friction log.

No Android device was connected (`adb devices -l` returned an empty list), so a
real password-manager popup and device logs could not be checked. This is a
credential metadata/lifecycle bug fix; the cold-start performance harness is not
needed under the project's minor bug-fix exception.

Flutter references: [autofill hints](https://api.flutter.dev/flutter/material/TextField/autofillHints.html)
and [autofill grouping and lifecycle](https://api.flutter.dev/flutter/widgets/AutofillGroup-class.html).
The password manager ultimately decides which stored credentials to suggest;
these domain hints do not establish website-side Digital Asset Links.
