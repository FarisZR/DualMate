---
module: Schedule
date: 2026-02-02
problem_type: ui_bug
component: onboarding_settings
symptoms:
  - "Selecting Rapla after skipping onboarding did not open the URL prompt"
root_cause: ui_state
resolution_type: code_fix
severity: low
tags: [rapla, onboarding, settings, dialog]
---

# Troubleshooting: Rapla URL prompt missing after skipping onboarding

## Problem
Users who skipped the Rapla URL step in onboarding could not reopen the Rapla URL
prompt from Settings unless they first switched to another schedule source and
back to Rapla. The Rapla option was already selected in the dialog, so tapping it
did nothing.

## Solution
Make the schedule source selection dialog allow re-selecting the same option and
always open the corresponding configuration prompt. This ensures tapping Rapla
always opens the Rapla URL dialog, even when Rapla is already selected.

**Code changes** (Dart):
```dart
// lib/schedule/ui/widgets/select_source_dialog.dart
RadioListTile<ScheduleSourceType>(
  toggleable: true,
  onChanged: (_) {
    sourceSelected(ScheduleSourceType.Rapla, context);
  },
)
```

## Commands run
```bash
flutter test
flutter run -d <DEVICE_ID>
```
