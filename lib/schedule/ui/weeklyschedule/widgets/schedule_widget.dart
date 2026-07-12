import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/common/ui/text_styles.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_render_data.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_entry_widget.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_current_time_indicator.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_grid.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_past_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduleWidget extends StatelessWidget {
  static const double _defaultTimeLabelsWidth = 54.0;
  static const double _defaultOverlapColumnGap = 6;
  static const double _defaultEventVerticalGap = 4;
  static const double _minimumEventExtent = 6;
  static const double _fullColumnThreshold = 0.999;
  static const double _compactColumnWidthThreshold = 64.0;
  static const double _compactWidthThreshold = 430.0;
  static final Map<String, _ScheduleDateFormatters> _formatterCacheByLocale =
      <String, _ScheduleDateFormatters>{};

  final Schedule schedule;
  final DateTime displayStart;
  final DateTime displayEnd;
  final DateTime now;
  final double displayStartHour;
  final double displayEndHour;
  final ScheduleEntryTapCallback onScheduleEntryTap;
  final bool showTimeLabels;
  final ScheduleRenderData? preparedData;
  final ValueListenable<ScheduleViewport>? viewportListenable;
  final ScheduleViewport? targetViewport;

  const ScheduleWidget({
    Key? key,
    required this.schedule,
    required this.displayStart,
    required this.displayEnd,
    required this.onScheduleEntryTap,
    required this.now,
    required this.displayStartHour,
    required this.displayEndHour,
    this.showTimeLabels = true,
    this.preparedData,
    this.viewportListenable,
    this.targetViewport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final viewport = viewportListenable;
        final width = constraints.biggest.width;
        final height = constraints.biggest.height;
        if (viewport == null || showTimeLabels) {
          return buildWithSize(
            context,
            width,
            height,
            ScheduleViewport(
              startHour: displayStartHour,
              endHour: displayEndHour,
            ),
          );
        }

        final renderData =
            preparedData ??
            ScheduleRenderData.prepare(
              schedule: schedule,
              displayStart: displayStart,
              displayEnd: displayEnd,
            );
        final days = renderData.displayedDays;
        final layoutProfile = _resolveLayoutProfile(width, days);
        final target =
            targetViewport ??
            ScheduleViewport(
              startHour: displayStartHour,
              endHour: displayEndHour,
            );

        return _buildAnimatedWithSize(
          context,
          width,
          height,
          renderData,
          layoutProfile,
          viewport,
          target,
        );
      },
    );
  }

  static bool isCompactLayout({
    required double width,
    required int days,
    required bool showTimeLabels,
  }) {
    assert(days > 0, 'days must be positive');
    final timeLabelWidth = showTimeLabels ? _defaultTimeLabelsWidth : 0.0;
    final availableColumnWidth = (width - timeLabelWidth) / days;
    return availableColumnWidth <= _compactColumnWidthThreshold ||
        width <= _compactWidthThreshold;
  }

  Widget _buildAnimatedWithSize(
    BuildContext context,
    double width,
    double height,
    ScheduleRenderData renderData,
    _ScheduleWidgetLayoutProfile layoutProfile,
    ValueListenable<ScheduleViewport> viewport,
    ScheduleViewport target,
  ) {
    final days = renderData.displayedDays;
    final dayLabelsHeight = layoutProfile.dayLabelsHeight;
    const timeLabelsWidth = 0.0;
    final targetVisibleHours = (target.endHour - target.startHour).clamp(
      1.0,
      24.0,
    );
    final targetHourHeight = (height - dayLabelsHeight) / targetVisibleHours;
    final targetMinuteHeight = targetHourHeight / 60;

    final staticLayers = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(
          key: const ValueKey<String>('schedule-entry-layer'),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              timeLabelsWidth,
              dayLabelsHeight,
              0,
              0,
            ),
            child: _AnimatedScheduleEntryLayer(
              renderData: renderData,
              layoutProfile: layoutProfile,
              viewport: viewport,
              targetViewport: target,
              onScheduleEntryTap: onScheduleEntryTap,
            ),
          ),
        ),
        RepaintBoundary(
          key: const ValueKey<String>('schedule-label-layer'),
          child: Stack(
            children: buildLabelWidgets(
              context,
              targetHourHeight,
              width / days,
              dayLabelsHeight,
              timeLabelsWidth,
              targetHourHeight,
              targetMinuteHeight,
              layoutProfile,
              target.startHour,
              target.endHour,
            ),
          ),
        ),
      ],
    );

    return ValueListenableBuilder<ScheduleViewport>(
      valueListenable: viewport,
      child: staticLayers,
      builder: (context, currentViewport, child) {
        final visibleHours =
            (currentViewport.endHour - currentViewport.startHour).clamp(
              1.0,
              24.0,
            );
        final hourHeight = (height - dayLabelsHeight) / visibleHours;
        final minuteHeight = hourHeight / 60;
        final currentTimeIndicatorGeometry =
            _resolveCurrentTimeIndicatorGeometry(
              days,
              minuteHeight,
              currentViewport.startHour,
              currentViewport.endHour,
            );

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ScheduleGrid(
              currentViewport.startHour,
              currentViewport.endHour,
              timeLabelsWidth,
              dayLabelsHeight,
              days,
              colorScheduleGridGridLines(context),
              key: const ValueKey<String>('schedule-grid-layer'),
            ),
            child!,
            RepaintBoundary(
              key: const ValueKey<String>('schedule-past-overlay-layer'),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  timeLabelsWidth,
                  dayLabelsHeight,
                  0,
                  0,
                ),
                child: SchedulePastOverlay(
                  currentViewport.startHour,
                  currentViewport.endHour,
                  colorScheduleInPastOverlay(context),
                  displayStart,
                  displayEnd,
                  now,
                  days,
                ),
              ),
            ),
            if (currentTimeIndicatorGeometry != null)
              RepaintBoundary(
                key: const ValueKey<String>(
                  'schedule-current-time-indicator-layer',
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    timeLabelsWidth,
                    dayLabelsHeight,
                    0,
                    0,
                  ),
                  child: ScheduleCurrentTimeIndicator(
                    dayIndex: currentTimeIndicatorGeometry.dayIndex,
                    columns: days,
                    yOffset: currentTimeIndicatorGeometry.yOffset,
                    color: colorCurrentTimeIndicator(context),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget buildWithSize(
    BuildContext context,
    double width,
    double height,
    ScheduleViewport viewport,
  ) {
    final renderData =
        preparedData ??
        ScheduleRenderData.prepare(
          schedule: schedule,
          displayStart: displayStart,
          displayEnd: displayEnd,
        );
    var days = renderData.displayedDays;
    final layoutProfile = _resolveLayoutProfile(width, days);

    var dayLabelsHeight = layoutProfile.dayLabelsHeight;
    var timeLabelsWidth = showTimeLabels ? layoutProfile.timeLabelsWidth : 0.0;

    final displayStartHour = viewport.startHour;
    final displayEndHour = viewport.endHour;
    final visibleHours = (displayEndHour - displayStartHour).clamp(1.0, 24.0);
    var hourHeight = (height - dayLabelsHeight) / visibleHours;
    var minuteHeight = hourHeight / 60;
    final currentTimeIndicatorGeometry = _resolveCurrentTimeIndicatorGeometry(
      days,
      minuteHeight,
      displayStartHour,
      displayEndHour,
    );

    var labelWidgets = buildLabelWidgets(
      context,
      hourHeight,
      (width - timeLabelsWidth) / days,
      dayLabelsHeight,
      timeLabelsWidth,
      hourHeight,
      minuteHeight,
      layoutProfile,
      displayStartHour,
      displayEndHour,
    );

    var entryWidgets = <Widget>[];

    entryWidgets = buildEntryWidgets(
      renderData,
      hourHeight,
      minuteHeight,
      width - timeLabelsWidth,
      days,
      layoutProfile,
      displayStartHour,
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
          key: const ValueKey<String>('schedule-grid-layer'),
        ),
        RepaintBoundary(
          key: const ValueKey<String>('schedule-entry-layer'),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              timeLabelsWidth,
              dayLabelsHeight,
              0,
              0,
            ),
            child: Stack(clipBehavior: Clip.hardEdge, children: entryWidgets),
          ),
        ),
        RepaintBoundary(
          key: const ValueKey<String>('schedule-label-layer'),
          child: Stack(children: labelWidgets),
        ),
        RepaintBoundary(
          key: const ValueKey<String>('schedule-past-overlay-layer'),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              timeLabelsWidth,
              dayLabelsHeight,
              0,
              0,
            ),
            child: SchedulePastOverlay(
              displayStartHour,
              displayEndHour,
              colorScheduleInPastOverlay(context),
              displayStart,
              displayEnd,
              now,
              days,
            ),
          ),
        ),
        if (currentTimeIndicatorGeometry != null)
          RepaintBoundary(
            key: const ValueKey<String>(
              'schedule-current-time-indicator-layer',
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                timeLabelsWidth,
                dayLabelsHeight,
                0,
                0,
              ),
              child: ScheduleCurrentTimeIndicator(
                dayIndex: currentTimeIndicatorGeometry.dayIndex,
                columns: days,
                yOffset: currentTimeIndicatorGeometry.yOffset,
                color: colorCurrentTimeIndicator(context),
              ),
            ),
          ),
      ],
    );
  }

  _CurrentTimeIndicatorGeometry? _resolveCurrentTimeIndicatorGeometry(
    int days,
    double minuteHeight,
    double displayStartHour,
    double displayEndHour,
  ) {
    final visibleStartDay = toStartOfDay(displayStart);
    final visibleEndDay = toStartOfDay(displayEnd);
    final currentDay = toStartOfDay(now);

    if (currentDay.isBefore(visibleStartDay) ||
        currentDay.isAfter(visibleEndDay)) {
      return null;
    }

    final dayIndex = currentDay.difference(visibleStartDay).inDays;
    if (dayIndex < 0 || dayIndex >= days) return null;

    final nowMinutes = (now.hour * 60) + now.minute;
    final startMinutes = displayStartHour * 60;
    final endMinutes = displayEndHour * 60;
    if (nowMinutes < startMinutes || nowMinutes >= endMinutes) {
      return null;
    }

    final yOffset = (nowMinutes - startMinutes) * minuteHeight;
    return _CurrentTimeIndicatorGeometry(dayIndex: dayIndex, yOffset: yOffset);
  }

  int calculateDisplayedDays() {
    var startEndDifference = toStartOfDay(
      displayEnd,
    ).difference(toStartOfDay(displayStart));

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
    double displayStartHour,
    double displayEndHour,
  ) {
    var labelWidgets = <Widget>[];
    final locale = L.of(context).locale;
    final formatters = _formatterCacheByLocale.putIfAbsent(
      locale.toLanguageTag(),
      () => _ScheduleDateFormatters(locale),
    );

    final firstHourLabel = displayStartHour.floor();
    final lastHourLabel = displayEndHour.ceil();
    if (showTimeLabels) {
      for (var hour = firstHourLabel; hour < lastHourLabel; hour++) {
        var hourLabelText = '$hour:00';

        labelWidgets.add(
          Positioned(
            top: rowHeight * (hour - displayStartHour) + dayLabelHeight,
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
    }

    var i = 0;

    var loopEnd = toStartOfDay(tomorrow(displayEnd));

    for (
      var columnDate = toStartOfDay(displayStart);
      columnDate.isBefore(loopEnd);
      columnDate = tomorrow(columnDate)
    ) {
      final isToday = isAtSameDay(columnDate, now);
      final dayNumber = formatters.dayNumber.format(columnDate);
      final monthShort = formatters.monthShort.format(columnDate);
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
                  formatters.dayShort.format(columnDate).toUpperCase(),
                  style: textStyleScheduleWidgetColumnTitleDay(
                    context,
                  ).copyWith(letterSpacing: 0.6),
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
                          : Theme.of(context).textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.86),
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
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
                        style: Theme.of(context).textTheme.titleMedium
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
                      color: Theme.of(
                        context,
                      ).textTheme.labelSmall?.color?.withValues(alpha: 0.8),
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
    ScheduleRenderData renderData,
    double hourHeight,
    double minuteHeight,
    double width,
    int columns,
    _ScheduleWidgetLayoutProfile layoutProfile,
    double displayStartHour,
  ) {
    if (renderData.schedule.entries.isEmpty) return <Widget>[];

    var entryWidgets = <Widget>[];

    var columnWidth = width / columns;
    final entriesByColumn = renderData.entriesByDay;

    for (int i = 0; i < columns; i++) {
      var xPosition = columnWidth * i;
      var maxWidth = columnWidth;

      entryWidgets.addAll(
        buildEntryWidgetsForColumn(
          maxWidth,
          hourHeight,
          minuteHeight,
          xPosition,
          entriesByColumn[i],
          layoutProfile,
          displayStartHour,
        ),
      );
    }

    return entryWidgets;
  }

  List<Widget> buildEntryWidgetsForColumn(
    double maxWidth,
    double hourHeight,
    double minuteHeight,
    double xPosition,
    List<PreparedScheduleEntry> entries,
    _ScheduleWidgetLayoutProfile layoutProfile,
    double displayStartHour,
  ) {
    var entryWidgets = <Widget>[];

    for (var value in entries) {
      var entry = value.entry;

      var rawYStart =
          hourHeight * (entry.start.hour - displayStartHour) +
          minuteHeight * entry.start.minute;

      var rawYEnd =
          hourHeight * (entry.end.hour - displayStartHour) +
          minuteHeight * entry.end.minute;

      var rawEntryLeft = maxWidth * value.leftColumn;
      var rawEntryWidth = maxWidth * (value.rightColumn - value.leftColumn);

      final compactMinInset = layoutProfile.compactPhone ? 0.1 : 1.0;
      var verticalInset =
          rawYEnd - rawYStart > (layoutProfile.eventVerticalGap + 6)
          ? layoutProfile.eventVerticalGap / 2
          : compactMinInset;
      final spansMultipleOverlapColumns =
          (value.rightColumn - value.leftColumn) < _fullColumnThreshold;
      final overlapMinInset = layoutProfile.compactPhone ? 0.25 : 1.0;
      final horizontalInset = spansMultipleOverlapColumns
          ? (rawEntryWidth > (layoutProfile.overlapColumnGap + 10)
                ? layoutProfile.overlapColumnGap / 2
                : overlapMinInset)
          : layoutProfile.dayBoundaryInset;

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
          renderedWidth: entryWidth,
          renderedHeight: eventHeight,
        ),
      );

      entryWidgets.add(widget);
    }

    return entryWidgets;
  }

  _ScheduleWidgetLayoutProfile _resolveLayoutProfile(double width, int days) {
    final compactPhone = isCompactLayout(
      width: width,
      days: days,
      showTimeLabels: showTimeLabels,
    );

    if (compactPhone) {
      return const _ScheduleWidgetLayoutProfile(
        compactPhone: true,
        dayLabelsHeight: 52,
        timeLabelsWidth: 46,
        overlapColumnGap: 0.8,
        eventVerticalGap: 1.2,
        dayLabelHorizontalPadding: 2,
        dayBoundaryInset: 0.0,
      );
    }

    return const _ScheduleWidgetLayoutProfile(
      compactPhone: false,
      dayLabelsHeight: 72,
      timeLabelsWidth: _defaultTimeLabelsWidth,
      overlapColumnGap: _defaultOverlapColumnGap,
      eventVerticalGap: _defaultEventVerticalGap,
      dayLabelHorizontalPadding: 4,
      dayBoundaryInset: 1.0,
    );
  }
}

class _AnimatedScheduleEntryLayer extends StatelessWidget {
  final ScheduleRenderData renderData;
  final _ScheduleWidgetLayoutProfile layoutProfile;
  final ValueListenable<ScheduleViewport> viewport;
  final ScheduleViewport targetViewport;
  final ScheduleEntryTapCallback onScheduleEntryTap;

  const _AnimatedScheduleEntryLayer({
    required this.renderData,
    required this.layoutProfile,
    required this.viewport,
    required this.targetViewport,
    required this.onScheduleEntryTap,
  });

  @override
  Widget build(BuildContext context) {
    final slots = <_PreparedEntrySlot>[];
    for (
      var dayIndex = 0;
      dayIndex < renderData.entriesByDay.length;
      dayIndex++
    ) {
      for (final entry in renderData.entriesByDay[dayIndex]) {
        slots.add(_PreparedEntrySlot(dayIndex: dayIndex, entry: entry));
      }
    }
    if (slots.isEmpty) return const SizedBox.expand();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return ClipRect(
          child: CustomMultiChildLayout(
            delegate: _ScheduleEntryLayoutDelegate(
              slots: slots,
              columns: renderData.displayedDays,
              layoutProfile: layoutProfile,
              viewport: viewport,
            ),
            children: <Widget>[
              for (var index = 0; index < slots.length; index++)
                LayoutId(
                  id: index,
                  child: _buildEntry(
                    slots[index],
                    _ScheduleEntryLayoutDelegate.resolveRect(
                      size: size,
                      slot: slots[index],
                      columns: renderData.displayedDays,
                      layoutProfile: layoutProfile,
                      viewport: targetViewport,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEntry(_PreparedEntrySlot slot, Rect targetRect) {
    return ScheduleEntryWidget(
      scheduleEntry: slot.entry.entry,
      onScheduleEntryTap: onScheduleEntryTap,
      renderedWidth: targetRect.width,
      renderedHeight: targetRect.height,
    );
  }
}

class _ScheduleEntryLayoutDelegate extends MultiChildLayoutDelegate {
  final List<_PreparedEntrySlot> slots;
  final int columns;
  final _ScheduleWidgetLayoutProfile layoutProfile;
  final ValueListenable<ScheduleViewport> viewport;

  _ScheduleEntryLayoutDelegate({
    required this.slots,
    required this.columns,
    required this.layoutProfile,
    required this.viewport,
  }) : super(relayout: viewport);

  @override
  void performLayout(Size size) {
    final currentViewport = viewport.value;
    for (var index = 0; index < slots.length; index++) {
      final rect = resolveRect(
        size: size,
        slot: slots[index],
        columns: columns,
        layoutProfile: layoutProfile,
        viewport: currentViewport,
      );
      layoutChild(index, BoxConstraints.tight(rect.size));
      positionChild(index, rect.topLeft);
    }
  }

  static Rect resolveRect({
    required Size size,
    required _PreparedEntrySlot slot,
    required int columns,
    required _ScheduleWidgetLayoutProfile layoutProfile,
    required ScheduleViewport viewport,
  }) {
    final columnWidth = size.width / columns;
    final visibleHours = (viewport.endHour - viewport.startHour).clamp(
      1.0,
      24.0,
    );
    final hourHeight = size.height / visibleHours;
    final minuteHeight = hourHeight / 60;
    final entry = slot.entry.entry;

    final rawYStart =
        hourHeight * (entry.start.hour - viewport.startHour) +
        minuteHeight * entry.start.minute;
    final rawYEnd =
        hourHeight * (entry.end.hour - viewport.startHour) +
        minuteHeight * entry.end.minute;
    final rawEntryLeft = columnWidth * slot.entry.leftColumn;
    final rawEntryWidth =
        columnWidth * (slot.entry.rightColumn - slot.entry.leftColumn);

    final compactMinInset = layoutProfile.compactPhone ? 0.1 : 1.0;
    final verticalInset =
        rawYEnd - rawYStart > (layoutProfile.eventVerticalGap + 6)
        ? layoutProfile.eventVerticalGap / 2
        : compactMinInset;
    final spansMultipleOverlapColumns =
        (slot.entry.rightColumn - slot.entry.leftColumn) <
        ScheduleWidget._fullColumnThreshold;
    final overlapMinInset = layoutProfile.compactPhone ? 0.25 : 1.0;
    final horizontalInset = spansMultipleOverlapColumns
        ? (rawEntryWidth > (layoutProfile.overlapColumnGap + 10)
              ? layoutProfile.overlapColumnGap / 2
              : overlapMinInset)
        : layoutProfile.dayBoundaryInset;

    final top = rawYStart + verticalInset;
    final height = (rawYEnd - rawYStart - (verticalInset * 2))
        .clamp(ScheduleWidget._minimumEventExtent, double.infinity)
        .toDouble();
    final left = (columnWidth * slot.dayIndex) + rawEntryLeft + horizontalInset;
    final width = (rawEntryWidth - (horizontalInset * 2))
        .clamp(ScheduleWidget._minimumEventExtent, double.infinity)
        .toDouble();

    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  bool shouldRelayout(covariant _ScheduleEntryLayoutDelegate oldDelegate) {
    return !identical(slots, oldDelegate.slots) ||
        columns != oldDelegate.columns ||
        layoutProfile != oldDelegate.layoutProfile ||
        !identical(viewport, oldDelegate.viewport);
  }
}

class _PreparedEntrySlot {
  final int dayIndex;
  final PreparedScheduleEntry entry;

  const _PreparedEntrySlot({required this.dayIndex, required this.entry});
}

class _ScheduleWidgetLayoutProfile {
  final bool compactPhone;
  final double dayLabelsHeight;
  final double timeLabelsWidth;
  final double overlapColumnGap;
  final double eventVerticalGap;
  final double dayLabelHorizontalPadding;
  final double dayBoundaryInset;

  const _ScheduleWidgetLayoutProfile({
    required this.compactPhone,
    required this.dayLabelsHeight,
    required this.timeLabelsWidth,
    required this.overlapColumnGap,
    required this.eventVerticalGap,
    required this.dayLabelHorizontalPadding,
    required this.dayBoundaryInset,
  });
}

class _ScheduleDateFormatters {
  final DateFormat dayShort;
  final DateFormat dayNumber;
  final DateFormat monthShort;

  _ScheduleDateFormatters(Locale locale)
    : dayShort = DateFormat("E", locale.toLanguageTag()),
      dayNumber = DateFormat("d", locale.toLanguageTag()),
      monthShort = DateFormat("MMM", locale.toLanguageTag());
}

class _CurrentTimeIndicatorGeometry {
  final int dayIndex;
  final double yOffset;

  const _CurrentTimeIndicatorGeometry({
    required this.dayIndex,
    required this.yOffset,
  });
}
