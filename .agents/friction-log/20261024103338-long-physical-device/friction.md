---
title: 'Long physical-device performance runs can lose their rendering surface to screen sleep'
severity: 'major'
issue: 'FarisZR/DualMate#141'
---

## Expected Behavior
A complete repeated physical-device performance run keeps rendering until every target finishes.

## Current Behavior
Android's inactivity timer can put the tablet to sleep during the suite. Flutter-generated gestures do not count as native user activity, and the test then waits for frames after the rendering surface is destroyed.

## Possible Solution
Temporarily keep a plugged-in device awake, wake it before the suite, and restore the previous charging policy on exit. Do not change animation speeds or the user's screen timeout.

## Minimal Reproducible Example
Run the full suite unattended with a screen timeout shorter than the total suite duration.

## Context
The connected Huawei tablet reported mWakefulness=Asleep midway through repeated customization runs. The interrupted measurement was discarded and the complete suite restarted.
