---
title: Preserve Rapla event types without tooltips
date: 2026-08-01
category: ui-bugs
tags:
  - rapla
  - schedule
  - parsing
---

# Preserve Rapla event types without tooltips

Some Rapla week entries contain only their visible time/title link and the
`week_block` inline background color. They do not contain the tooltip,
infotable, or strong-tag type metadata that older responses used.

## Cause

The no-tooltip fallback in `RaplaParsingUtils.extractScheduleDetailsFromCell`
always assigned `ScheduleEntryType.Unknown`, so entries using the newer markup
lost their event category.

## Fix

The fallback now uses a centralized repository-owned color map for the known
Rapla colors: class, exam, public holiday, and special event. Unknown colors
remain `ScheduleEntryType.Unknown`. Tooltip and strong-tag classification is
unchanged and remains the source of truth whenever a tooltip is present.

## Verification

- `flutter test test/schedule/service/rapla`
- `dart format --output=none --set-exit-if-changed` on the changed Dart files
- `flutter analyze` scoped to the changed parser and test files
