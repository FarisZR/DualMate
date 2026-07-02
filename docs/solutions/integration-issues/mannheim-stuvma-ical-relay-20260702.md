---
module: Schedule Sources
date: 2026-07-02
problem_type: integration_issue
component: mannheim_schedule_source
symptoms:
  - "DHBW Mannheim schedule setup depended on the dead legacy backend"
  - "Mannheim users needed a dedicated setup flow instead of the raw iCal URL screen"
root_cause: mannheim_schedule_source_used_removed_legacy_php_calendar_backend
resolution_type: code_fix
severity: medium
tags: [schedule, mannheim, ical, onboarding]
---

# Troubleshooting: DHBW Mannheim StuV iCal relay setup

## Problem
The old Mannheim setup loaded courses from a legacy PHP calendar endpoint. That
backend is no longer usable, so Mannheim setup could not reliably produce a
working schedule source.

## Root Cause
Mannheim had its own course scraper/parser for a legacy HTML form. Runtime
schedule loading already supports iCal, so maintaining Mannheim-specific event
parsing was unnecessary and kept the app coupled to the dead backend.

## Solution
- Replaced Mannheim course loading with the StuV Mannheim relay calendar list.
- Converted each relay profile name into a safely encoded StuV profile iCal URL.
- Kept `ScheduleSourceType.Mannheim` as the persisted source type for UI and
  analytics clarity.
- Gated Mannheim runtime setup so only StuV profile URLs are accepted, then
  delegated actual schedule loading to the existing iCal source.
- Added local course search, empty states, and retry handling to the Mannheim
  setup UI.
- Removed the legacy Mannheim HTML parser, scraper, test, and fixture.

## Test Coverage
- Mannheim relay JSON parsing and course mapping.
- Safe profile URL generation.
- Local course search and selection.
- Empty, no-results, and retry UI states.
- Mannheim setup persistence and generated iCal URL storage.
- Mannheim runtime setup using the iCal-backed source.
- Stale non-StuV Mannheim configuration becoming setup-required.

## Commands run
```bash
flutter test test/schedule/service/mannheim/mannheim_course_service_test.dart test/ui/onboarding/viewmodels/mannheim_view_model_test.dart test/ui/onboarding/mannheim_page_test.dart test/schedule/business/schedule_source_provider_mannheim_test.dart test/ui/onboarding/onboarding_list_tile_material_test.dart
rg -n "<old Mannheim host>" lib test docs
```
