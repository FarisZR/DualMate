---
module: Dates UI
date: 2026-02-02
problem_type: ui_bug
component: layout
symptoms:
  - "Date blocks were uniformly tall, even for single holidays"
  - "Test week sections did not scale with sub-appointments"
root_cause: fixed_layout
resolution_type: code_fix
severity: low
tags: [dates, layout, list, flutter, ui]
---

# Troubleshooting: Date blocks too tall for single events

## Problem
The dates page displayed uniform, large blocks for all sections. Simple events like holidays looked oversized, while multi-appointment sections did not scale naturally.

## Environment
- Module: Dates UI
- Rails Version: N/A (Flutter)
- Affected Component: Important event section cards
- Date: 2026-02-02

## Symptoms
- Single events occupied the same height as multi-event sections.
- Tablets used a fixed grid aspect ratio, forcing uniform heights.

## What Didn't Work

**Attempted Solution 1:** Keep a 2-column grid with a fixed `childAspectRatio`.
- **Why it failed:** Fixed aspect ratios enforce uniform heights, hiding differences between single and multi-event sections.

## Solution

Use a list layout for all form factors and make single-event sections more compact via tighter padding and visual density.

**Code changes:**
```dart
// date_management_page.dart
return ListView.separated(
  controller: _raplaScrollController,
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  itemBuilder: (context, index) {
    if (index < sections.length) {
      return ImportantEventSectionCard(
        key: ValueKey('section_$index'),
        section: sections[index],
      );
    }
    return _buildRaplaFooter(model, context);
  },
  separatorBuilder: (context, index) => const SizedBox(height: 12),
  itemCount: itemCount,
);
```

```dart
// important_event_section_card.dart
final isSingleEventSection =
    section.header == null && section.events.length == 1;

return ImportantEventTile(
  event: event,
  contentPadding: compact
      ? const EdgeInsets.fromLTRB(16, 2, 16, 2)
      : const EdgeInsets.fromLTRB(16, 4, 16, 4),
  visualDensity: compact ? const VisualDensity(vertical: -3) : null,
);
```

## Why This Works
List layouts allow each card to size to its content. By compacting only single-event sections, holidays and simple events become slimmer while multi-event sections expand naturally.

## Prevention
- Avoid fixed grid aspect ratios when content height varies.
- Tune padding and density for single-item sections instead of forcing uniform sizes.

## Related Issues
- [swipe-unloaded-week-no-fetch-schedule-ui-20260127](../ui-bugs/swipe-unloaded-week-no-fetch-schedule-ui-20260127.md)
