---
module: Dualis UI
date: 2026-02-12
problem_type: ui_bug
component: frontend_flutter
symptoms:
  - "Password manager apps no longer fill Dualis password after recent branch changes"
  - "Username/password fields are not reliably recognized as login fields"
  - "Credentials saved for https://dualis.dhbw.de/ are not suggested consistently"
root_cause: missing_autofill_metadata
resolution_type: code_fix
severity: medium
tags: [dualis, login, autofill, password-manager, android]
---

# Troubleshooting: Dualis password autofill not detected

## Problem
On branch `performance-refractor`, password manager apps stopped reliably autofilling the Dualis login credentials in app login forms.

## Root Cause
The shared credentials widget used plain `TextField`s without autofill metadata grouping/hints, and the submit/save flows did not finalize the autofill context.

Without explicit autofill hints, Android autofill services have lower confidence that fields represent a username/password pair. Without finishing the autofill context on successful credential actions, save/update prompts can be missed.

## Solution
- Updated shared login widget `lib/ui/login_credentials_widget.dart`:
  - Wrapped fields in `AutofillGroup`
  - Added username/password autofill hints
  - Added best-effort Dualis affinity hints (`dualis.dhbw.de`, `https://dualis.dhbw.de/`)
  - Kept existing submit/focus behavior
- Updated credential submit/save flows to finalize context with:
  - `TextInput.finishAutofillContext(shouldSave: true)`
  - Applied in onboarding Dualis credential test path and schedule-source credentials dialog save path
- Added widget regression tests in:
  - `test/ui/login_credentials_widget_autofill_test.dart`

## Notes
- This is best-effort domain affinity from app metadata.
- Strict app↔website credential binding still depends on website-side Digital Asset Links and cannot be guaranteed from Flutter field metadata alone.

## Test Coverage
- `exposes Dualis autofill hints for username and password`
- `keeps submit behavior for focus handoff and password submit`

## Commands run
```bash
flutter test test/ui/login_credentials_widget_autofill_test.dart
```
