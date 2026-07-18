---
title: Class reminder feature
date: 2026-07-18
status: implemented
---

# Class reminder feature

## Architecture

- Extract stable canonical class-name normalization from visual schedule prettification.
- Persist recurring and one-time rules plus a scheduled-notification manifest in sqflite.
- Reconcile only refreshed windows through one serialized, coalescing queue.
- Schedule exact Android notifications with deterministic persisted identifiers.
- Keep foreground refreshes non-blocking and drain reminder work in background refreshes.
- Bulk-delete past occurrence data while retaining recurring class-name rules.
- Preserve configuration and expose a paused state when notification or exact-alarm permission is unavailable.
- Clear and cancel source-scoped reminders before an actual schedule-source change.

## Delivery slices

1. Canonical identity and deterministic IDs.
2. Persistent rules, manifest, and bulk cleanup.
3. Incremental coordinator, queue, exact scheduling, lifecycle, reboot, and telemetry integration.
4. Material 3 configuration sheet, schedule indicators, permission banner, and source-change confirmation.
5. Automated regression coverage plus Galaxy S21+ deployment and interaction verification.
