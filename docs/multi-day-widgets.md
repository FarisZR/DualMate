# Multi-Day Home Screen Widgets

## Overview

The schedule and canteen Android home screen widgets now display multiple days. Each day is a single row with the date on the left and the classes/meals on the right. The number of days shown depends on the widget height.

## Behavior

- **Week-only lookahead:** The widgets scan a rolling 7-day window (today plus 6 days) to limit database work.
- **Today always visible:** Today is always shown, even if there are no remaining classes or meals.
- **Skip empty future days:** Future days without entries are omitted.
- **Marker events:** Rapla marker events like `Klausurwoche`, theory-phase starts, and public holidays stay visible, but render first in each day as compact title-only rows.
- **State styling:** Schedule items are styled as past (grayed), current (brighter gray), or future (normal).
- **Overflow:** When a day has more items than fit, the row ends with a "+N more" indicator.

## Layout

- Left column: localized weekday and date
- Right column: list of classes/meals
- Rows grow based on item count (variable height)

## Performance Notes

- One range query per widget update (week range)
- Row height calculation uses lightweight constants to avoid measurement overhead
- Widget height is read from `OPTION_APPWIDGET_MIN_HEIGHT` to keep content within bounds
