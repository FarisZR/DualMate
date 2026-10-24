---
title: 'Cold-navigation setup assumes a modal phone drawer on tablets'
severity: 'major'
issue: 'FarisZR/DualMate#140'
---

## Expected Behavior
The cold-navigation harness can reach every main screen on the connected tablet.

## Current Behavior
The setup waits for a phone menu button that does not exist in the permanent tablet navigation layout. Three fresh Canteen runs time out before reaching content.

## Possible Solution
Select destinations directly from the permanent panel and mark drawer-only animation scenarios inapplicable on tablets.

## Minimal Reproducible Example
Run PERF_TARGET=canteen on a landscape tablet wider than the app's large-screen breakpoint.

## Context
Found during the required full cold-start performance validation for timetable customization. The harness now reports permanent-navigation checks separately from drawer animation checks.
