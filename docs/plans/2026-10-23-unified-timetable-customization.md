---
title: Unified timetable customization
date: 2026-10-23
type: feature
---

Students can combine modules from several DHBW classes, including timetables
using different source formats. The timetable's Customize action owns source
management and module selection; onboarding still configures the first source.

The original timetable includes modules by default and preserves existing hidden
module names. Added timetables require explicit module selection. Choices belong
to a source, so identically named modules in different classes stay independent.
Future modules follow each timetable's default. Editing and removing timetables
and selecting modules remain drafts until Save changes.

Use the provided light/dark mockups as the design direction with Flutter Material
components, DualMate's red palette and typography, rounded selectable rows,
expandable class groups, and a plain surface around the save action. Support
German, English, dark/light themes, accessibility, phones and tablets.

Keep one combined cache for the timetable, dates, native widgets, background
updates and notifications. Preserve existing configuration on upgrade. Selection
changes must cancel hidden lesson alarms without generating timetable-change
alerts. Source replacement must remove obsolete notification state. Cover
issues #133, #135 and #136 with regression tests.

Validate SQLite migration, independent source choices, refresh and offline
behavior, notification filtering, narrow layouts, tablet interaction and both
themes. Run the cold-navigation performance harness and include screenshots in
the pull request. The user also requested the current stable Flutter and
dependency/toolchain versions.
