---
title: Isolating exact class reminders from schedule-change notifications
date: 2026-07-18
category: notifications
tags:
  - schedule
  - reminders
  - exact-alarms
  - android
  - regression-testing
---

# Isolating exact class reminders from schedule-change notifications

An immediate notification headed "Weitere Vorlesung" is emitted by the existing
background schedule-change flow when a refresh discovers an added class. It is
not a timed class reminder and is intentionally independent of the class start
time. A class reminder instead uses reminder-specific copy such as "Recht
beginnt in 30 Minuten" and is scheduled for `classStart - offset`.

Class reminders now reserve negative deterministic notification identifiers.
The existing immediate-notification API uses non-negative random identifiers,
so the two notification families cannot replace or cancel one another through
an Android identifier collision. Reminder copy uses DualMate's saved language
rather than the device locale, including singular German and English wording.

Regression coverage verifies exact Android scheduling, the requested local
trigger time, elapsed-trigger suppression, stable identity, queue serialization,
canonical recurring matching, schedule-change notifications, and the evening
next-day notification. A Galaxy S21+ profile build also delivered a dedicated
`class_reminders` notification from an `RTC_WAKEUP` alarm with a zero window at
the expected offset.
