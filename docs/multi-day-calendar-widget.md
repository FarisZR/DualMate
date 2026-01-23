# Multi-Day Calendar Widget Feature

## Overview
The Schedule Today Widget has been enhanced to display multiple days of schedule entries based on the widget's height. This allows users to see their schedule for several days ahead by resizing the widget on their home screen.

## Implementation Details

### Components Modified

1. **ScheduleProvider.kt**
   - Added `queryScheduleEntriesForDays(startDate: LocalDate, numDays: Int)` method to fetch schedule entries for multiple consecutive days
   - Reuses existing database query logic to maintain consistency

2. **ScheduleTodayWidget.kt**
   - Implemented `onAppWidgetOptionsChanged()` to handle widget resize events
   - Added `calculateNumDaysFromHeight()` to determine how many days to display based on widget height:
     - < 200dp: 1 day (today only)
     - 200-320dp: 2 days
     - 320-440dp: 3 days
     - 440-560dp: 4 days
     - 560-680dp: 5 days
     - 680-800dp: 6 days
     - 800+dp: 7 days (one week)
   - Updated `hasScheduleEntriesForDays()` to check multiple days for empty state
   - Modified `updateScheduleEntryList()` to pass number of days to the RemoteViewsService

3. **ScheduleEntryViewsFactory.kt**
   - Refactored to support multiple view types (date headers and schedule entries)
   - Added `WidgetListItem` sealed class to represent different item types
   - Implemented date grouping logic to organize entries by day
   - Date headers are only shown when displaying multiple days
   - Returns `getViewTypeCount() = 2` to support both view types

4. **TodayScheduleEntryRemoteViewsService.kt**
   - Modified to receive and pass `numDays` parameter to the factory
   - Extracts widget ID and number of days from intent extras

5. **WidgetListItem.kt** (NEW)
   - Sealed class defining two types: `DateHeader` and `ScheduleEntryItem`
   - Provides type-safe representation of list items

6. **widget_date_header.xml** (NEW)
   - Simple layout displaying the date in a readable format (e.g., "Monday, 24.01.2024")
   - Styled to match the widget's overall design
   - Supports both light and dark themes

7. **colors.xml** (UPDATED)
   - Added `widget_date_header_background` and `widget_date_header_text_color` for both light and dark themes

8. **AndroidManifest.xml**
   - Registered `ScheduleTodayWidget` receiver and `TodayScheduleEntryRemoteViewsService` service

## User Experience

### Single Day Mode (Small Widget)
When the widget height is less than 200dp, it shows only today's schedule without date headers, maintaining the original simple layout.

### Multi-Day Mode (Larger Widget)
When the widget is expanded vertically:
1. Each day gets a date header showing the day name and date
2. Schedule entries are grouped under their respective dates
3. Empty days are included (showing just the header) to provide continuity
4. The widget automatically refreshes when resized

## Testing

To test this feature:
1. Add the "Schedule Today" widget to the home screen
2. Resize the widget vertically to different heights
3. Verify that the number of days shown increases with height
4. Check that date headers appear correctly when showing multiple days
5. Verify proper theming in both light and dark modes

## Technical Notes

- The widget uses Android's `AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT` to determine size
- Height thresholds are in density-independent pixels (dp)
- The implementation maintains backward compatibility with single-day display
- Date formatting uses the system locale for proper internationalization
- The sealed class pattern ensures type safety when handling different list item types

## Future Enhancements

Potential improvements for future versions:
- Allow users to configure the number of days manually via widget settings
- Add week/weekend indicators
- Show week numbers
- Add "scroll to top" functionality for very tall widgets
- Implement swipe gestures to navigate between date ranges
