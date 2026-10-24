---
title: 'Integration driver exits before finally cleanup'
severity: 'minor'
issue: 'FarisZR/DualMate#144'
---

## Expected Behavior
The visual driver exports its optional native video after the device test completes.

## Current Behavior
Flutter integration_test_driver_extended.integrationDriver terminates the driver with exit(0) or exit(1), bypassing a surrounding finally block and leaving the recording on the device.

## Possible Solution
Use responseDataCallback with writeResponseOnFailure to await export before exit. This is implemented in the timetable visual driver.

## Minimal Reproducible Example
Wrap await integrationDriver() in try/finally and record a cleanup marker in finally. Complete a successful test; the marker is not written.

## Context
Encountered while recording the timetable loading UI on Pixel 8 Pro with Flutter 3.47.8.
