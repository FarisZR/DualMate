import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/common/ui/text_styles.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_entry_alignment.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_entry_widget.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_grid.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_past_overlay.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduleWidget extends StatelessWidget {
  static const double _defaultColumnGap = 6;
  static const double _defaultEventVerticalGap = 4;
  static const double _minimumEventExtent = 6;

  final Schedule schedule;
  final DateTime displayStart;
  final DateTime displayEnd;
  final DateTime now;
  final int displayStartHour;
  final int displayEndHour;
  final ScheduleEntryTapCallback onScheduleEntryTap;

  const ScheduleWidget({
    Key? key,
    required this.schedule,
    required this.displayStart,
    required this.displayEnd,
    required this.onScheduleEntryTap,
    required this.now,
    required this.displayStartHour,
    required this.displayEndHour,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return buildWithSize(
          context,
          constraints.biggest.width,
          constraints.biggest.height,
        );
      },
    );
  }

  Widget buildWithSize(BuildContext context, double width, double height) {
    var days = calculateDisplayedDays();
    final layoutProfile = _resolveLayoutProfile(width, days);

    var dayLabelsHeight = layoutProfile.dayLabelsHeight;
    var timeLabelsWidth = layoutProfile.timeLabelsWidth;

    var hourHeight =
        (height - dayLabelsHeight) / (displayEndHour - displayStartHour);
    var minuteHeight = hourHeight / 60;

    var labelWidgets = buildLabelWidgets(
      context,
      hourHeight,
      (width - timeLabelsWidth) / days,
      dayLabelsHeight,
      timeLabelsWidth,
      hourHeight,
      minuteHeight,
      layoutProfile,
    );

    var entryWidgets = <Widget>[];

    entryWidgets = buildEntryWidgets(
      hourHeight,
      minuteHeight,
      width - timeLabelsWidth,
      days,
      layoutProfile,
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ScheduleGrid(
          displayStartHour,
          displayEndHour,
          timeLabelsWidth,
          dayLabelsHeight,
          days,
          colorScheduleGridGridLines(context),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(timeLabelsWidth, dayLabelsHeight, 0, 0),
          child: Stack(
            children: entryWidgets,
          ),
        ),
        Stack(
          children: labelWidgets,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(timeLabelsWidth, dayLabelsHeight, 0, 0),
          child: SchedulePastOverlay(
            displayStartHour,
            displayEndHour,
            colorScheduleInPastOverlay(context),
            displayStart,
            displayEnd,
            now,
            days,
          ),
        )
      ],
    );
  }

  int calculateDisplayedDays() {
    var startEndDifference =
        toStartOfDay(displayEnd).difference(toStartOfDay(displayStart));

    var days = startEndDifference.inDays + 1;

    if (days > 7) {
      days = 7;
    } else if (days < 5) {
      days = 5;
    }
    return days;
  }

  List<Widget> buildLabelWidgets(
    BuildContext context,
    double rowHeight,
    double columnWidth,
    double dayLabelHeight,
    double timeLabelWidth,
    double hourHeight,
    double minuteHeight,
    _ScheduleWidgetLayoutProfile layoutProfile,
  ) {
    var labelWidgets = <Widget>[];

    for (var i = displayStartHour; i < displayEndHour; i++) {
      var hourLabelText = i.toString() + ":00";

      labelWidgets.add(
        Positioned(
          top: rowHeight * (i - displayStartHour) + dayLabelHeight,
          left: 0,
          child: Padding(
            padding: layoutProfile.compactPhone
                ? const EdgeInsets.fromLTRB(2, 2, 2, 6)
                : const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(hourLabelText),
          ),
        ),
      );
    }

    var i = 0;

    var dayFormatter = DateFormat("E", L.of(context).locale.languageCode);
    var dayNumberFormatter = DateFormat("d", L.of(context).locale.languageCode);
    var monthFormatter = DateFormat("MMM", L.of(context).locale.languageCode);

    var loopEnd = toStartOfDay(tomorrow(displayEnd));

    for (var columnDate = toStartOfDay(displayStart);
        columnDate.isBefore(loopEnd);
        columnDate = tomorrow(columnDate)) {
      final isToday = isAtSameDay(columnDate, now);
      final dayNumber = dayNumberFormatter.format(columnDate);
      final monthShort = monthFormatter.format(columnDate);
      labelWidgets.add(
        Positioned(
          top: 0,
          left: columnWidth * i + timeLabelWidth,
          width: columnWidth,
          height: dayLabelHeight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              layoutProfile.dayLabelHorizontalPadding,
              0,
              layoutProfile.dayLabelHorizontalPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  dayFormatter.format(columnDate).toUpperCase(),
                  style:
                      textStyleScheduleWidgetColumnTitleDay(context).copyWith(
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                if (layoutProfile.compactPhone)
                  Text(
                    '$dayNumber $monthShort',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.86),
                          fontWeight:
                              isToday ? FontWeight.w700 : FontWeight.w500,
                        ),
                  )
                else ...[
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        dayNumber,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                      ),
                    )
                  else
                    Text(
                      dayNumber,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                          ),
                    ),
                  const SizedBox(height: 1),
                  Text(
                    monthShort,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.color
                              ?.withValues(alpha: 0.8),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );

      i++;
    }

    return labelWidgets;
  }

  List<Widget> buildEntryWidgets(
    double hourHeight,
    double minuteHeight,
    double width,
    int columns,
    _ScheduleWidgetLayoutProfile layoutProfile,
  ) {
    if (schedule.entries.isEmpty) return <Widget>[];

    var entryWidgets = <Widget>[];

    var columnWidth = width / columns;
    final entriesByColumn = _buildEntriesByColumn(columns);
    var columnStartDate = toStartOfDay(displayStart);

    for (int i = 0; i < columns; i++) {
      var xPosition = columnWidth * i;
      var maxWidth = columnWidth;

      entryWidgets.addAll(buildEntryWidgetsForColumn(
        maxWidth,
        hourHeight,
        minuteHeight,
        xPosition,
        entriesByColumn[columnStartDate] ?? const <ScheduleEntry>[],
        layoutProfile,
      ));

      columnStartDate = tomorrow(columnStartDate);
    }

    return entryWidgets;
  }

  Map<DateTime, List<ScheduleEntry>> _buildEntriesByColumn(int columns) {
    final result = <DateTime, List<ScheduleEntry>>{};
    final columnStarts = <DateTime>[];
    var cursor = toStartOfDay(displayStart);

    for (var i = 0; i < columns; i++) {
      columnStarts.add(cursor);
      result[cursor] = <ScheduleEntry>[];
      cursor = tomorrow(cursor);
    }

    for (final entry in schedule.entries) {
      for (final dayStart in columnStarts) {
        final dayEnd = tomorrow(dayStart);
        if (entry.start.isBefore(dayEnd) && entry.end.isAfter(dayStart)) {
          result[dayStart]!.add(entry);
        }
      }
    }

    return result;
  }

  List<Widget> buildEntryWidgetsForColumn(
    double maxWidth,
    double hourHeight,
    double minuteHeight,
    double xPosition,
    List<ScheduleEntry> entries,
    _ScheduleWidgetLayoutProfile layoutProfile,
  ) {
    var entryWidgets = <Widget>[];

    var laidOutEntries =
        ScheduleEntryAlignmentAlgorithm().layoutEntries(entries);

    for (var value in laidOutEntries) {
      var entry = value.entry;

      var rawYStart = hourHeight * (entry.start.hour - displayStartHour) +
          minuteHeight * entry.start.minute;

      var rawYEnd = hourHeight * (entry.end.hour - displayStartHour) +
          minuteHeight * entry.end.minute;

      var rawEntryLeft = maxWidth * value.leftColumn;
      var rawEntryWidth = maxWidth * (value.rightColumn - value.leftColumn);

      var verticalInset =
          rawYEnd - rawYStart > (layoutProfile.eventVerticalGap + 6)
              ? layoutProfile.eventVerticalGap / 2
              : 1.0;
      var horizontalInset = rawEntryWidth > (layoutProfile.columnGap + 10)
          ? layoutProfile.columnGap / 2
          : 1.0;

      var yStart = rawYStart + verticalInset;
      var eventHeight = (rawYEnd - rawYStart - (verticalInset * 2))
          .clamp(_minimumEventExtent, double.infinity)
          .toDouble();

      var entryLeft = rawEntryLeft + horizontalInset;
      var entryWidth = (rawEntryWidth - (horizontalInset * 2))
          .clamp(_minimumEventExtent, double.infinity)
          .toDouble();

      var widget = Positioned(
        top: yStart,
        left: entryLeft + xPosition,
        height: eventHeight,
        width: entryWidth,
        child: ScheduleEntryWidget(
          scheduleEntry: entry,
          onScheduleEntryTap: onScheduleEntryTap,
        ),
      );

      entryWidgets.add(widget);
    }

    return entryWidgets;
  }

  _ScheduleWidgetLayoutProfile _resolveLayoutProfile(double width, int days) {
    final availableColumnWidth = (width - 54.0) / days;
    final compactPhone = availableColumnWidth <= 64 || width <= 430;

    if (compactPhone) {
      return const _ScheduleWidgetLayoutProfile(
        compactPhone: true,
        dayLabelsHeight: 52,
        timeLabelsWidth: 46,
        columnGap: 2,
        eventVerticalGap: 2,
        dayLabelHorizontalPadding: 2,
      );
    }

    return const _ScheduleWidgetLayoutProfile(
      compactPhone: false,
      dayLabelsHeight: 72,
      timeLabelsWidth: 54,
      columnGap: _defaultColumnGap,
      eventVerticalGap: _defaultEventVerticalGap,
      dayLabelHorizontalPadding: 4,
    );
  }
}

class _ScheduleWidgetLayoutProfile {
  final bool compactPhone;
  final double dayLabelsHeight;
  final double timeLabelsWidth;
  final double columnGap;
  final double eventVerticalGap;
  final double dayLabelHorizontalPadding;

  const _ScheduleWidgetLayoutProfile({
    required this.compactPhone,
    required this.dayLabelsHeight,
    required this.timeLabelsWidth,
    required this.columnGap,
    required this.eventVerticalGap,
    required this.dayLabelHorizontalPadding,
  });
}
