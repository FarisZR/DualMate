---
title: Reliable class reminders with incremental reconciliation
date: 2026-07-18
category: features
tags:
  - schedule
  - reminders
  - notifications
  - android
---

# Reliable class reminders with incremental reconciliation

Class reminders are stored separately from schedule rows so recurring rules survive cache replacement and one-time rules can reconnect to moved occurrences. Recurring identity uses `CanonicalClassName`, which applies the title-cleaning rules even when visual prettification is disabled.

`ClassReminderController` enqueues refreshed in-memory windows after schedule persistence. `ReminderSyncQueue` serializes work, coalesces overlapping requests, and drops requests from an old source generation. `ClassReminderCoordinator` compares desired alarms with the local manifest and performs only changed schedules, cancellations, and batched manifest writes. Foreground refreshes only enqueue; background refreshes drain the queue before returning.

Android alarms use `exactAllowWhileIdle`, deterministic IDs, a dedicated notification channel, and the plugin boot receiver. Notification taps reuse the schedule widget payload path to open the relevant week and class details.

Permission loss cancels manifest-backed alarms without deleting rules. Permission restoration reconciles the upcoming 14-day window. Past one-time rules and manifest rows are bulk-deleted by class start time, while recurring rules remain until explicit removal or a confirmed source change.
