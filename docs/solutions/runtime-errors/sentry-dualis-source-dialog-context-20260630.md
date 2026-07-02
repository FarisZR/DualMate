---
module: Schedule source settings
date: 2026-06-30
problem_type: runtime_error
component: frontend_flutter
sentry_issue: DUALMATE-M
root_cause: popped_dialog_context_reused_for_followup_dialog
resolution_type: code_fix
severity: medium
tags: [sentry, dualis, schedule-source, dialog, flutter, android]
---

# Troubleshooting: Dualis source dialog context crash

## Problem

Sentry issue `DUALMATE-M` reported an unhandled `TypeError: Null check operator
used on a null value` when selecting Dualis as the schedule source from the
settings flow. The latest event showed this in-app path:

- `SelectSourceDialog.sourceSelected`
- `EnterDualisCredentialsDialog.show`
- Flutter `showDialog`
- `Navigator.of`
- `StatefulElement.state`

Users never saw the Dualis credentials dialog because the crash happened while
Flutter tried to resolve the navigator for the follow-up dialog.

## Root Cause

`SelectSourceDialog` popped its own dialog and then reused that dialog builder's
`BuildContext` to open the Dualis credentials dialog. After the pop, that context
belonged to a detached element. Flutter's `showDialog` needs the context to find
the navigator and capture inherited themes, so the stale context failed inside
`Navigator.of(context)`.

The same sequencing also committed the selected schedule source before the
follow-up configuration dialog completed.

## Solution

`SelectSourceDialog.show(context)` now treats the source picker as a value
selector:

1. show the source dialog and return the selected `ScheduleSourceType`
2. close only the source dialog from the dialog builder context
3. after `showDialog` completes, use the original caller context for the
   follow-up configuration dialog
4. guard the follow-up with `context.mounted`
5. commit configured sources only when their setup dialogs save successfully

For Dualis, selecting the radio option now opens the credentials dialog from the
still-mounted settings/schedule page context. The source is committed only after
the user confirms credentials and `setupForDualis()` runs.

## Test Coverage

- selecting Dualis opens the credentials dialog without reusing the disposed
  source dialog context
- selecting Dualis does not commit the schedule source before credentials are
  accepted
- selecting No schedule still closes the source dialog and initializes the empty
  source

## Commands

```bash
flutter test test/schedule/ui/widgets/select_source_dialog_test.dart
flutter test test/ui/settings/settings_page_lifecycle_test.dart
flutter test test/ui/login_credentials_widget_autofill_test.dart
flutter analyze \
  lib/schedule/ui/widgets/select_source_dialog.dart \
  lib/schedule/ui/widgets/enter_dualis_credentials_dialog.dart \
  test/schedule/ui/widgets/select_source_dialog_test.dart
```
