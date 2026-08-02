---
title: Parse Rapla v2 metadata without tooltips
date: 2026-08-02
category: ui-bugs
tags:
  - rapla
  - schedule
  - parsing
  - metadata
---

# Parse Rapla v2 metadata without tooltips

Rapla v2 calendar cells can omit the legacy tooltip. In that format the anchor
contains the time and reservation title, followed by sibling `person` and
`resource` spans. The schedule detail view was parsing the anchor with a fixed
HTML offset, which left time/title content in `details` and discarded the
lecturer and room metadata.

## Contract and compatibility

The upstream `HTMLRaplaBlock` implementation in `/home/clawd/rapla` emits the
tooltip when enabled and otherwise emits the anchor followed by person and
resource spans. No response-level Rapla version marker is emitted, so the
parser uses capability detection: tooltip-present cells retain the v1.x parser;
tooltip-free cells use the sibling-span structure.

## Fix

- Extract the no-tooltip title from DOM nodes after the anchor's first `br`.
- Collect all non-empty person and resource spans, preserving HTML entities for
  the existing sanitizer to decode consistently.
- Keep no-tooltip details empty so time, title, lecturer, and room markup are
  not duplicated there.
- Preserve the existing tooltip classification and no-tooltip color/type map.

## Verification

- Added sanitized v1 tooltip and v2 no-tooltip metadata regressions covering
  title, details, professor, room, and type.
- `flutter test test/schedule/service/rapla/rapla_metadata_parsing_test.dart`
  (2 tests passed)
- `flutter test test/schedule` (262 tests passed)
- `flutter analyze` (no issues)
- `dart format --output=none --set-exit-if-changed` on changed Dart files
- `git diff --check`
- Connected Galaxy S21+ validation with the sanitized fixture on 5 October
  2026 showed the title, both lecturers, `Class`, and both rooms in the
  detail sheet with no duplicated details.
- `ANDROID_SERIAL=RFCR31468LJ PERF_RUNS=3
  scripts/run_cold_navigation_perf_suite.sh` completed successfully across
  all six targets and wrote the cold-start summary.
