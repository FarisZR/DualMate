---
title: 'Physical-device performance previews use a test-controlled frame cadence'
severity: 'major'
issue: 'FarisZR/DualMate#139'
---

## Expected Behavior
The physical-device performance harness renders animations at the display cadence.

## Current Behavior
The inherited live-test frame policy only renders requested test frames. Actions that call pumpAndSettle with its default 100 ms step visibly advance animations in steps and provide very few samples.

## Possible Solution
Use the fullyLive frame policy for device performance and visual QA tests. Keep timeline tracing separate from ranking runs.

## Minimal Reproducible Example
Run the customization profile flow with the inherited policy and compare its route transition frame count against fullyLive on the same tablet.

## Context
Found while investigating reported dropped frames during physical-device timetable customization previews. The full cold-navigation harness now explicitly opts into live frame scheduling as well.
