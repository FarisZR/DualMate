---
module: Schedule & Date Management
date: 2026-02-02
problem_type: ui_bug
component: pagination
symptoms:
  - "First load only shows about 3 months of dates"
  - "No additional pages fetch until the user scrolls"
root_cause: logic_error
resolution_type: code_fix
severity: medium
tags: [rapla, pagination, first-load, date-management]
---

# Troubleshooting: First-load dates pagination stops after 3 months

## Problem
On the initial open, the dates list populated only the first page (about a
3-month window) and did not fetch further pages until the user scrolled.

## Environment
- Module: Schedule & Date Management
- Affected Component: Date management pagination
- Date: 2026-02-02

## Symptoms
- First load stops after roughly 3 months of dates.
- Additional pages do not load unless the user scrolls.

## Solution
Trigger a small prefetch loop on first open when the list does not fill the
viewport, and keep the empty state hidden until initial loading completes.

## Why This Works
- Pagination no longer depends solely on scroll position, so the first view can
  fetch the next pages automatically.
- The empty state no longer flashes while the initial pages are loading.

## Prevention
- Add a first-load pagination test that asserts more than one page is fetched.
- Treat empty or short content as a signal to prefetch additional pages.
