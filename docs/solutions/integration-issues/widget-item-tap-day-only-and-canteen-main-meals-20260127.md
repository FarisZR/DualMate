---
module: Android widgets (schedule/canteen)
date: 2026-01-27
problem_type: behavior_change
component: remoteviews
symptoms:
  - "Widget item taps should only open the day"
  - "Canteen widget should show only choice 1/2"
root_cause: product_change
resolution_type: code_change
severity: low
tags: [android-widget, remoteviews, canteen, schedule]
---

# Widget item taps should open day only

## Change
- Schedule/canteen widget item taps now behave like day header taps and only pass the day start to navigation.
- Canteen widget only shows main meals (Wahlessen 1/2). Other meals are collapsed into a "+x more" line that links to the day.

## Implementation
- Removed per-entry extras from widget item click intents.
- Added a visible-items filter in the canteen widget to select only main meals and compute hidden counts.
- Added overflow tap handling to route to the day.

## Result
- All widget taps open the correct day/week without per-item detail navigation.
- Canteen widget stays compact while still indicating hidden items.
