---
title: 'Canteen weekday normalization fails across autumn DST'
severity: 'minor'
---

## Expected Behavior
Saturday normalizes to Monday midnight in Europe/Berlin.

## Current Behavior
On 2026-10-24, adding Duration(days: 2) yields Sunday 23:00 after DST ends; canteen content-day fixtures become empty.

## Possible Solution
Use calendar-day arithmetic and add DST-specific coverage.

## Minimal Reproducible Example
Compare DateTime(2026, 10, 24).add(const Duration(days: 2)) under TZ=Europe/Berlin and TZ=UTC. The canteen page and bounds-test helper use this arithmetic.

## Context
Found while validating issue #146. UTC tests exercise the intended menu fixtures; local-time tests encounter this separate date bug.
