# Multi-Day Calendar Widget - Testing Guide

## Overview
The Schedule Today Widget now automatically adjusts the number of days displayed based on its height. This guide explains how to test the feature.

## Testing Steps

### 1. Add the Widget
1. Long-press on the Android home screen
2. Tap "Widgets"
3. Find "DHBW Studenten App" widgets
4. Drag "Schedule Today" widget to the home screen

### 2. Test Single Day Mode (Default)
- The widget should initially show today's schedule only
- No date headers should be visible
- Layout matches the original single-day design

### 3. Test Multi-Day Mode
1. Long-press on the widget to enter resize mode
2. Drag the bottom edge downward to increase height
3. Observe the widget updating to show multiple days:
   - At ~200dp height: Shows 2 days with date headers
   - At ~320dp height: Shows 3 days with date headers
   - At ~440dp height: Shows 4 days
   - Continue expanding to see up to 7 days

### 4. Verify Date Headers
When showing multiple days, each day should have:
- A date header showing: "Day Name, DD.MM.YYYY" (e.g., "Monday, 24.01.2024")
- Schedule entries grouped under that date
- Proper spacing and styling

### 5. Test Empty Days
- Days without schedule entries should still show their date header
- The empty state message should appear only if ALL displayed days are empty

### 6. Test Theme Support
1. Switch device to dark mode
2. Verify widget colors adjust properly:
   - Date headers use dark theme colors
   - Schedule entries maintain proper contrast
   
### 7. Test Widget Refresh
1. Resize the widget multiple times
2. Widget should update smoothly without crashes
3. Data should remain consistent

## Expected Behavior

### Height Thresholds
| Height Range | Days Shown |
|--------------|------------|
| < 200dp      | 1 day      |
| 200-320dp    | 2 days     |
| 320-440dp    | 3 days     |
| 440-560dp    | 4 days     |
| 560-680dp    | 5 days     |
| 680-800dp    | 6 days     |
| 800+dp       | 7 days     |

### Visual Design
- Date headers have a subtle background color
- Headers use bold text
- Schedule entry cards maintain original styling
- Proper spacing between days

## Known Limitations
- Maximum 7 days can be displayed
- Widget must be online to fetch initial schedule data
- Date format is European style (DD.MM.YYYY)

## Troubleshooting

### Widget Not Updating
1. Long-press widget → Remove
2. Re-add the widget
3. Try resizing again

### No Data Showing
1. Open the main app
2. Ensure schedule is synced
3. Check that Rapla/Dualis credentials are valid
4. Return to home screen and refresh widget

### Incorrect Number of Days
- Check the device screen density
- Very high or low DPI screens may have different thresholds
- Log messages will show actual height detected (check logcat)

## Development Notes

### Debugging
Use `adb logcat` to see widget update messages:
```bash
adb logcat | grep ScheduleTodayWidget
```

Look for messages like:
```
Widget height: 320dp, showing 3 days
```

### Force Widget Update
You can trigger an update programmatically by:
1. Calling `ScheduleTodayWidget.requestWidgetRefresh(context)`
2. Or updating schedule data in the app

## Success Criteria
- ✅ Widget displays 1 day by default (small size)
- ✅ Widget expands to show 2-7 days when resized
- ✅ Date headers appear correctly in multi-day mode
- ✅ No date headers in single-day mode
- ✅ Empty days are handled properly
- ✅ Widget updates smoothly on resize
- ✅ Dark mode is properly supported
- ✅ No crashes or visual glitches
