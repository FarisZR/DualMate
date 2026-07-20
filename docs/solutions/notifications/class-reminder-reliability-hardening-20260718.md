---
title: Hardening class-reminder lifecycle, filtering, and Android permissions
date: 2026-07-18
category: notifications
tags:
  - schedule
  - reminders
  - permissions
  - filters
  - performance
  - android
---

# Hardening class-reminder lifecycle, filtering, and Android permissions

The first class-reminder implementation had several cross-layer reliability
risks that were not visible in the core scheduling tests. A lifecycle callback
could query reminder permissions before `NotificationApi` had been registered,
temporarily treating an unavailable dependency as a permission denial. The
schedule page then mounted and removed the paused banner during startup, which
also changed the weekly schedule's widget structure while its initial refresh
animation was running.

Reminder permission state now remains unknown until the notification service is
ready and all three required checks complete: application notification access,
the dedicated `class_reminders` channel, and exact-alarm access. Unknown state
never pauses reminders, cancels alarms, or renders muted reminder indicators.
The schedule subtree remains mounted under a stable layout while only the notice
height and opacity animate. Reminder actions remain disabled until controller
initialization completes, and permission repair opens one Android settings
surface at a time.

Schedule filtering is treated as a presentation decision rather than evidence
that Rapla removed an occurrence. Reminder reconciliation consumes the
unfiltered schedule immediately after persistence, while the normal UI callback
continues to receive the filtered schedule. When a user hides a class that has
reminders, the filter page explicitly offers to keep the reminders or hide the
class and remove them. Reminder-bearing rows show a bell so hidden reminder
state is discoverable.

One-time reminders now preserve ambiguous same-title moves instead of silently
deleting the user's rule. Exact matches are preferred, followed by a unique
same-time rename and then a unique nearest occurrence within a guarded window.
An authoritative refresh with no plausible occurrence still removes the rule.
Moved rules are persisted even when their notification time has already passed.

Rapla source identity now excludes transient date and navigation parameters,
normalizes scheme and host casing, and orders stable query parameters. Copying
the same calendar URL while viewing another week therefore does not clear
reminders. Notification navigation uses the actual schedule title rather than
the canonical matching title, so detail resolution also works when visual
prettification is disabled.

For rendering performance, schedule cards no longer resolve the reminder
controller or attach one listener per entry. The weekly entry layer owns one
listener, uses indexed rule lookup, and passes the resolved reminder state into
each card. Rule reloads notify only when effective reminder state changes, and
foreground schedule refreshes only enqueue reminder reconciliation after the
unfiltered schedule is persisted.

## Battery-restriction fallback

Exact allow-while-idle alarms remain the default delivery mechanism. DualMate
does not proactively ask users to disable battery optimization after creating a
reminder.

On controller initialization and app resume, DualMate checks the existing
reminder manifest before expired rows are cleaned up. A reminder is considered
likely missed only when its scheduled time is at least ten minutes in the past
and its deterministic notification ID is still present in
`flutter_local_notifications`' pending queue. A fired one-shot notification is
removed from that queue, so absence from the queue is not treated as proof of a
miss or delivery.

Detected stale alarms are cancelled and removed from the manifest, then one
compact localized notice is shown above the schedule. The notice links Galaxy
devices to Samsung's Never sleeping apps screen and falls back to Android's
battery-optimization settings and then the app-details screen. No direct
battery-optimization exemption permission is requested.

Reminder saves for entries that have already started are ignored before any
permission check, persistence, or reconciliation work. The existing reminder
button and removal flow remain unchanged.

# Verification

- Full Flutter suite: 572 tests passed.
- Android JVM/unit build: `:app:testDebugUnitTest` passed.
- `flutter analyze` passed without issues.
- Regression coverage includes startup dependency readiness, confirmed
  permission denial, channel disablement, settings routing, unfiltered reminder
  reconciliation, filter keep/remove/cancel behavior, ambiguous one-time moves,
  stable Rapla source identity, notification title resolution, and one reminder
  listener for a multi-entry weekly schedule. It also covers the missed-alarm
  queue heuristic, its grace period and permission boundary, localized notice
  behavior, and the early guard for already-started entries.
- Galaxy S21+ profile-mode verification covers cold launch, schedule refresh
  animation, filter interaction, permission notice behavior, the compact
  missed-reminder notice, and opening Samsung's Never sleeping apps screen.
