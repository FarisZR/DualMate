# Canteen Menu Feature

## Overview
The canteen feature provides a performant, swipeable daily menu for the DHBW Karlsruhe canteen (Menseria Erzbergerstraße). It includes:

- Day-by-day swipe navigation (weekdays only)
- Dietary filters (all, no pork, vegetarian, vegan)
- Emoji-based food type indicators
- Offline cache + SQLite storage for widgets
- An Android home screen widget styled with the modern widget visuals

## Architecture

### Data flow
1. The UI asks `CanteenViewModel` for the current day.
2. The view model lazily requests data for the week containing that day.
3. `CanteenProvider` loads cached data from SQLite first, then refreshes from the network.
4. `CanteenScraper` fetches the HTML and parses it in a background isolate.
5. Parsed meals are batched into SQLite for fast widget access.

### Core files
- Scraper/Parser: `lib/canteen/service/canteen_scraper.dart`, `lib/canteen/service/canteen_parser.dart`
- Persistence: `lib/canteen/data/canteen_meal_repository.dart`, `lib/canteen/data/canteen_meal_entity.dart`
- View model: `lib/canteen/ui/viewmodels/canteen_view_model.dart`
- UI: `lib/canteen/ui/canteen_page.dart`, `lib/canteen/ui/widgets/meal_card.dart`
- Widget: `android/app/src/main/kotlin/de/bennik2000/dhbwstudentapp/widget/canteen` + `android/app/src/main/res/layout/widget_canteen_today.xml`

## Data Source
- Provider: Studierendenwerk Karlsruhe
- URL: `https://www.sw-ka.de/de/hochschulgastronomie/speiseplan/mensa_erzberger/?kw=<week>`
- Week calculation uses ISO week numbers (see `_isoWeekNumber()` in `CanteenScraper`).

## Parsing Rules
- Days are read from `#canteen_day_nav_1..5` using their `rel` date attribute.
- Meals are extracted from `.mensatype_rows` and `.meal-detail-table`.
- Food type icons (`img` tags) map to emoji badges:
  - vegan: 🌱
  - vegetarian: 🥬
  - pork: 🐷
  - beef: 🐄
  - poultry: 🍗
  - fish: 🐟
  - mensavital: 💪
- Allergen markers in brackets (e.g. `[Se,Sf]`) are expanded using `AllergenLegend`.
- Day-level notes like `"Zu jedem Gericht reichen wir Apfel oder Salat"` are removed as menu entries and attached to each meal as `"Apfel oder Salat inklusive"`.

## Storage
- Meals are stored in SQLite table `canteen_meals` for widget access.
- Columns: `date`, `name`, `category`, `price`, `notes`, `meal_types`.
- Inserts are batched to avoid blocking the UI thread during refresh.

## UI Behavior

### Weekday-only pagination
The daily page view does not allow weekends. Instead, the page index is mapped to a weekday-only sequence:

- The base page corresponds to the current weekday.
- Page offsets are translated into ISO weekdays and mapped to Monday–Friday only.
- Weekends are never emitted by the page date resolver, preventing jitter during fast swipes.

### Smooth loading
To avoid frame drops while loading a new week:

- The HTML parsing happens in a background isolate.
- The UI shows animated skeleton cards while a week is loading.
- The day list switches from skeleton to real content using a short fade.
- Chips are not rendered in the list (notes are shown as a lightweight text row).

### Filters
The filter dropdown (top-right) uses `CanteenFilter` to filter the list in-memory, without re-querying the network or database.

## Widget

- Android widget shows today’s meals.
- Data is read directly from SQLite via `CanteenProvider` on Android.
- Widget layout uses the modern widget styling (same background as `ScheduleNowWidget`).
- Refreshes are triggered together with schedule widgets via `WidgetUpdateCallback` and `AndroidScheduleTodayWidget`.

## Performance Notes

- Parsing: `Isolate.run()` keeps HTML parsing off the UI thread.
- Storage: `DatabaseAccess.insertBatch()` avoids per-row insert overhead.
- UI: Skeleton list animation uses one shared controller to avoid per-card rebuilds.
- Meal cards avoid heavy widgets (no chips, limited text lines).

## Troubleshooting

- If the menu fails to load, check the ISO week calculation and the HTML selectors.
- If widgets show empty state, confirm `canteen_meals` has entries for today.
- If the UI becomes janky again, verify that parsing still happens in the isolate and that chips have not been reintroduced.

## Maintenance Checklist

- Verify the canteen URL and week parameter still match the Studierendenwerk site.
- Re-run parser tests after any HTML structure change.
- Check the allergen legend mapping for new or renamed codes.
- Confirm emoji mapping matches the current icon titles on the website.
- Validate widget layout after Android SDK updates (RemoteViews restrictions can change).
- Ensure database migration stays in sync with `canteen_meals` schema changes.

## Operational Runbook

### Common symptoms

- Menu is empty for days that should have meals.
- Widget shows "No meals for today" even though data exists.
- UI feels sluggish or swipe stutters after a data refresh.

### Debugging steps

1. **Verify the HTML source**
   - Fetch the menu page in a browser and confirm the day navigation entries still use `rel` attributes.
   - Inspect a meal entry to ensure `.mensatype_rows`, `.meal-detail-table`, and `.menu-title` are still present.

2. **Check week calculation**
   - Verify the ISO week number matches the site’s week label.
   - If weeks mismatch, update `_isoWeekNumber()` in `CanteenScraper`.

3. **Confirm parser output**
   - Run: `flutter test test/canteen`
   - If parsing fails, update the selectors or the day note detection in `CanteenParser`.

4. **Validate database contents**
   - Use `sqflite` inspector or `adb shell` to check `canteen_meals` for today’s date.
   - If missing, verify `CanteenProvider.refreshWeek()` is writing rows and that batching is still enabled.

5. **Widget rendering**
   - Ensure `CanteenProvider` on Android can open the database path.
   - Confirm widget refresh is triggered via `WidgetUpdateCallback` and `AndroidScheduleTodayWidget`.

6. **Performance regressions**
   - Confirm parsing still runs in an isolate (`Isolate.run`).
   - Ensure notes remain text-only (avoid reintroducing chips).
   - Validate skeleton loading is active for empty/first load states.

### Recovery actions

- Clear app data to force a fresh database rebuild if data is corrupted.
- Remove and re-add the widget to refresh RemoteViews.
- If the site is down, display the empty state and avoid retry loops.
