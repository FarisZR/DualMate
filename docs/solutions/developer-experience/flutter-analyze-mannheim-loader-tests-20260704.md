---
module: Developer Experience
date: 2026-07-04
problem_type: ci_failure
component: github_actions_analyze
symptoms:
  - "flutter analyze failed in GitHub Actions on MannheimCourseLoader test doubles"
root_cause: test_loaders_kept_old_zero_argument_signature_after_cancellation_token_was_added
resolution_type: test_fix
severity: low
tags: [ci, flutter-analyze, mannheim, tests]
---

# Troubleshooting: Mannheim loader test doubles after cancellation support

## Problem
GitHub Actions failed during `flutter analyze` because Mannheim onboarding tests
passed zero-argument async functions into `MannheimViewModel`.

## Root Cause
`MannheimCourseLoader` now accepts an optional `CancellationToken`, but the test
doubles still used the previous zero-argument function shape.

## Solution
- Updated Mannheim view-model and widget test loaders to accept the cancellation
  token argument.
- Kept test behavior unchanged because these tests do not need to inspect the
  token.

## Test Coverage
- `flutter analyze`
- `flutter test test/ui/onboarding/viewmodels/mannheim_view_model_test.dart test/ui/onboarding/onboarding_list_tile_material_test.dart`
