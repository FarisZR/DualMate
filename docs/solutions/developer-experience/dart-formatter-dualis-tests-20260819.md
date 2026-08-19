---
module: Developer Experience
date: 2026-08-19
problem_type: tooling
component: dart_formatter
symptoms:
  - "The formatter reports legacy Dualis tests as changed during focused validation"
root_cause: legacy_test_wrapping_predates_the_current_dart_formatter
resolution_type: dedicated_formatting_change
severity: low
tags: [dart, formatter, dualis, tests]
issue: FarisZR/DualMate#122
---

# Normalize the legacy Dualis test formatting

The current Dart formatter changed wrapping in two existing Dualis test files.
Formatting those files as part of an unrelated bugfix created avoidable
churn, so they were normalized in this dedicated formatting change:

- `test/dualis/ui/viewmodels/study_grades_view_model_test.dart`
- `test/dualis/ui/study_overview_loading_animation_test.dart`

Future focused checks can validate touched Dart files without rewriting
unrelated legacy code:

```sh
dart format --output=none --set-exit-if-changed path/to/touched_file.dart
```

The check is clean for both normalized Dualis tests.

