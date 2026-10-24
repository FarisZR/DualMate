---
title: 'Four canteen paging tests fail on the unchanged v2 branch'
severity: 'minor'
issue: 'FarisZR/DualMate#138'
---

## Expected Behavior
Canteen paging widget tests pass on the base branch.

## Current Behavior
The four bounds tests for content retention, next-week preload, and loading transitions fail on both the unchanged v2 checkout with Flutter 3.44.4 and the customization branch with Flutter 3.47.8.

## Possible Solution
Investigate the fixture and current-day selection independently.

## Minimal Reproducible Example
Run flutter test test/canteen/ui/canteen_page_bounds_test.dart on commit 602cb2a.

## Context
Observed while running the full regression suite for timetable customization; confirmed against the untouched checkout.
