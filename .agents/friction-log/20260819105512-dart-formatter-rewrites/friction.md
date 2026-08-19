---
title: 'Dart formatter rewrites legacy Dualis test formatting'
severity: 'minor'
---

## Expected Behavior
The repository formatter check should validate touched tests without rewriting unrelated legacy formatting.

## Current Behavior
The current Dart formatter reports both touched Dualis test files as changed even though their existing surrounding formatting is repository-consistent. Formatting them wholesale creates unrelated churn.

## Possible Solution
Pin the repository formatter version or update the affected legacy test files in a dedicated formatting change.

## Minimal Reproducible Example
Run dart format --output=none --set-exit-if-changed on the touched Dualis test files.

## Context
This was encountered while validating a minimal study-grade error-handling change. The focused and affected Flutter tests and flutter analyze pass, and git diff --check is clean.
