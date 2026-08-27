import 'dart:math' as math;

import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/date_management/business/important_event_ordering.dart';
import 'package:dualmate/date_management/model/date_entry.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

DateTime _toUtcCalendarDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

class DatesRenderData {
  static const int _noticeableGapDays = 7;

  final List<RaplaListItem> raplaItems;
  final Map<String, int> raplaIndexByKey;
  final List<DateEntryRenderData> dateEntries;
  final DateTime? nextPastStateChange;

  const DatesRenderData._({
    required this.raplaItems,
    required this.raplaIndexByKey,
    required this.dateEntries,
    required this.nextPastStateChange,
  });

  // ignore: cyclomatic-complexity
  factory DatesRenderData.prepare({
    required List<ImportantEventSection> sections,
    required List<DateEntry> entries,
    required String locale,
    required DateTime now,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy', locale);
    final timeFormat = DateFormat.Hm(locale);
    final weekdayFormat = DateFormat.E(locale);
    final monthFormat = DateFormat.MMM(locale);
    final semanticDateFormat = DateFormat.yMMMMEEEEd(locale);
    final strings = L(Locale(locale));
    final eventDataByEvent = <ImportantEvent, ImportantEventRenderData>{};

    ImportantEventRenderData renderEvent(ImportantEvent event) {
      return eventDataByEvent.putIfAbsent(
        event,
        () => ImportantEventRenderData.prepare(
          event: event,
          now: now,
          timeFormat: timeFormat,
          weekdayFormat: weekdayFormat,
          monthFormat: monthFormat,
          semanticDateFormat: semanticDateFormat,
          rangeConnector: strings.dateManagementAgendaRangeConnector,
          pastLabel: strings.dateManagementAgendaPast,
        ),
      );
    }

    final raplaItems = <RaplaListItem>[];
    ImportantEventRenderData? previousVisibleEvent;
    var afterSectionHeading = false;

    for (final section in sections) {
      final sectionKey = _stableSectionKey(section);
      if (section.kind == ImportantEventSectionKind.examWeek) {
        final headerData = renderEvent(section.header!);
        raplaItems.add(
          RaplaListItem.sectionHeading(
            stableKey: 'heading:$sectionKey',
            sectionKey: sectionKey,
            sectionKind: section.kind,
            heading: ImportantEventSectionHeadingRenderData(
              title: section.header!.title,
              rangeSubtitle: headerData.compactRangeText,
              semanticsLabel:
                  '${section.header!.title}, ${headerData.semanticDateText}',
            ),
          ),
        );
        previousVisibleEvent = null;
        afterSectionHeading = true;
      }

      for (final event in section.events) {
        final eventData = renderEvent(event);
        final hasNoticeableGap =
            previousVisibleEvent != null &&
            _toUtcCalendarDay(event.start)
                    .difference(
                      _toUtcCalendarDay(previousVisibleEvent.event.end),
                    )
                    .inDays >=
                _noticeableGapDays;
        final suppressDateRail =
            !afterSectionHeading &&
            previousVisibleEvent != null &&
            previousVisibleEvent.event.isSingleDay &&
            event.isSingleDay &&
            isAtSameDay(previousVisibleEvent.event.start, event.start);
        final spacingRole = afterSectionHeading
            ? AgendaRowSpacingRole.afterSectionHeading
            : previousVisibleEvent == null && raplaItems.isEmpty
            ? AgendaRowSpacingRole.first
            : suppressDateRail
            ? AgendaRowSpacingRole.sameDayContinuation
            : hasNoticeableGap
            ? AgendaRowSpacingRole.distantDateChange
            : AgendaRowSpacingRole.normalDateChange;
        raplaItems.add(
          RaplaListItem.eventRow(
            stableKey:
                'event:$sectionKey:${importantEventStableIdentity(event)}',
            sectionKey: sectionKey,
            sectionKind: section.kind,
            row: ImportantEventAgendaRowRenderData(
              event: eventData,
              suppressDateRail: suppressDateRail,
              spacingRole: spacingRole,
            ),
          ),
        );
        previousVisibleEvent = eventData;
        afterSectionHeading = false;
      }
      if (section.events.isEmpty) afterSectionHeading = false;
    }

    final indexByKey = <String, int>{};
    for (var index = 0; index < raplaItems.length; index++) {
      indexByKey[raplaItems[index].stableKey] = index;
    }

    final dateEntries = List<DateEntryRenderData>.unmodifiable(
      entries.map(
        (entry) => DateEntryRenderData.prepare(
          entry: entry,
          dateFormat: dateFormat,
          timeFormat: timeFormat,
          now: now,
        ),
      ),
    );

    DateTime? nextPastStateChange;
    void considerPastStateChange(DateTime end) {
      if (!end.isAfter(now)) return;
      if (nextPastStateChange == null || end.isBefore(nextPastStateChange!)) {
        nextPastStateChange = end;
      }
    }

    for (final event in eventDataByEvent.values) {
      considerPastStateChange(event.event.end);
    }
    for (final entry in dateEntries) {
      considerPastStateChange(entry.entry.end);
    }

    return DatesRenderData._(
      raplaItems: List<RaplaListItem>.unmodifiable(raplaItems),
      raplaIndexByKey: Map<String, int>.unmodifiable(indexByKey),
      dateEntries: dateEntries,
      nextPastStateChange: nextPastStateChange,
    );
  }

  int? indexForKey(Key key) {
    return key is ValueKey<String> ? raplaIndexByKey[key.value] : null;
  }

  static String _stableSectionKey(ImportantEventSection section) {
    if (section.kind == ImportantEventSectionKind.standalone) {
      return 'standalone:${importantEventStableIdentity(section.events.single)}';
    }
    final header = section.header!;
    return 'exam-week:${normalizeImportantEventTitle(header.title)}:'
        '${_calendarDayKey(header.start)}:${_calendarDayKey(header.end)}';
  }

  static String _calendarDayKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

enum ImportantEventRangeStyle { singleDay, sameMonth, crossMonth, crossYear }

class ImportantEventRenderData {
  final ImportantEvent event;
  final String stableKey;
  final String weekday;
  final String startDay;
  final String startMonth;
  final String? startYear;
  final String? endDay;
  final String? endMonth;
  final String? endYear;
  final ImportantEventRangeStyle rangeStyle;
  final String? timeText;
  final String semanticDateText;
  final String semanticsLabel;
  final String compactRangeText;
  final bool isPast;

  const ImportantEventRenderData({
    required this.event,
    required this.stableKey,
    required this.weekday,
    required this.startDay,
    required this.startMonth,
    required this.startYear,
    required this.endDay,
    required this.endMonth,
    required this.endYear,
    required this.rangeStyle,
    required this.timeText,
    required this.semanticDateText,
    required this.semanticsLabel,
    required this.compactRangeText,
    required this.isPast,
  });

  factory ImportantEventRenderData.prepare({
    required ImportantEvent event,
    required DateTime now,
    required DateFormat timeFormat,
    required DateFormat weekdayFormat,
    required DateFormat monthFormat,
    required DateFormat semanticDateFormat,
    required String rangeConnector,
    required String pastLabel,
  }) {
    final isPast = event.end.isBefore(now);
    final rangeStyle = _rangeStyle(event);
    final startMonth = _monthText(monthFormat, event.start);
    final endMonthText = _monthText(monthFormat, event.end);
    final isCurrentYear = event.start.year == now.year;
    final startYear = switch (rangeStyle) {
      ImportantEventRangeStyle.singleDay =>
        isCurrentYear ? null : event.start.year.toString(),
      ImportantEventRangeStyle.sameMonth =>
        isCurrentYear ? null : event.start.year.toString(),
      ImportantEventRangeStyle.crossMonth => null,
      ImportantEventRangeStyle.crossYear => event.start.year.toString(),
    };
    final endYear = switch (rangeStyle) {
      ImportantEventRangeStyle.singleDay ||
      ImportantEventRangeStyle.sameMonth => null,
      ImportantEventRangeStyle.crossMonth =>
        isCurrentYear ? null : event.end.year.toString(),
      ImportantEventRangeStyle.crossYear => event.end.year.toString(),
    };
    final endDay = event.isSingleDay
        ? null
        : event.end.day.toString().padLeft(2, '0');
    final visibleEndMonth = switch (rangeStyle) {
      ImportantEventRangeStyle.singleDay ||
      ImportantEventRangeStyle.sameMonth => null,
      ImportantEventRangeStyle.crossMonth ||
      ImportantEventRangeStyle.crossYear => endMonthText,
    };
    final semanticStart = semanticDateFormat.format(event.start);
    final semanticDateText = event.isSingleDay
        ? semanticStart
        : '$semanticStart $rangeConnector ${semanticDateFormat.format(event.end)}';
    final timeText = event.isSingleDay && event.hasTime
        ? timeFormat.format(event.start)
        : null;
    final semanticsParts = <String>[
      semanticDateText,
      event.title,
      if (timeText != null) timeText,
      if (event.professor.trim().isNotEmpty) event.professor,
      if (isPast) pastLabel,
    ];
    final compactRangeText = _compactRangeText(
      style: rangeStyle,
      startDay: event.start.day.toString().padLeft(2, '0'),
      endDay: endDay,
      startMonth: startMonth,
      endMonth: visibleEndMonth,
      startYear: startYear,
      endYear: endYear,
    );

    return ImportantEventRenderData(
      event: event,
      stableKey: importantEventStableIdentity(event),
      weekday: weekdayFormat.format(event.start).replaceAll('.', ''),
      startDay: event.start.day.toString(),
      startMonth: startMonth,
      startYear: startYear,
      endDay: endDay,
      endMonth: visibleEndMonth,
      endYear: endYear,
      rangeStyle: rangeStyle,
      timeText: timeText,
      semanticDateText: semanticDateText,
      semanticsLabel: semanticsParts.join(', '),
      compactRangeText: compactRangeText,
      isPast: isPast,
    );
  }

  static ImportantEventRangeStyle _rangeStyle(ImportantEvent event) {
    if (event.isSingleDay) return ImportantEventRangeStyle.singleDay;
    if (event.start.year != event.end.year) {
      return ImportantEventRangeStyle.crossYear;
    }
    if (event.start.month != event.end.month) {
      return ImportantEventRangeStyle.crossMonth;
    }
    return ImportantEventRangeStyle.sameMonth;
  }

  static String _monthText(DateFormat format, DateTime date) {
    return format.format(date).replaceAll('.', '').toUpperCase();
  }

  static String _compactRangeText({
    required ImportantEventRangeStyle style,
    required String startDay,
    required String? endDay,
    required String startMonth,
    required String? endMonth,
    required String? startYear,
    required String? endYear,
  }) {
    switch (style) {
      case ImportantEventRangeStyle.singleDay:
        return '$startDay $startMonth${_yearSuffix(startYear)}';
      case ImportantEventRangeStyle.sameMonth:
        return '$startDay–$endDay $startMonth${_yearSuffix(startYear)}';
      case ImportantEventRangeStyle.crossMonth:
        return '$startDay $startMonth – $endDay $endMonth'
            '${_yearSuffix(endYear)}';
      case ImportantEventRangeStyle.crossYear:
        return '$startDay $startMonth $startYear – '
            '$endDay $endMonth $endYear';
    }
  }

  static String _yearSuffix(String? year) => year == null ? '' : ' $year';
}

class ImportantEventAgendaRowRenderData {
  final ImportantEventRenderData event;
  final bool suppressDateRail;
  final AgendaRowSpacingRole spacingRole;

  const ImportantEventAgendaRowRenderData({
    required this.event,
    required this.suppressDateRail,
    required this.spacingRole,
  });
}

enum AgendaRowSpacingRole {
  first,
  sameDayContinuation,
  normalDateChange,
  distantDateChange,
  afterSectionHeading,
}

class ImportantEventSectionHeadingRenderData {
  final String title;
  final String rangeSubtitle;
  final String semanticsLabel;

  const ImportantEventSectionHeadingRenderData({
    required this.title,
    required this.rangeSubtitle,
    required this.semanticsLabel,
  });
}

enum RaplaListItemKind { sectionHeading, eventRow }

class RaplaListItem {
  final String stableKey;
  final String sectionKey;
  final ImportantEventSectionKind sectionKind;
  final RaplaListItemKind kind;
  final ImportantEventSectionHeadingRenderData? heading;
  final ImportantEventAgendaRowRenderData? row;

  const RaplaListItem.sectionHeading({
    required this.stableKey,
    required this.sectionKey,
    required this.sectionKind,
    required ImportantEventSectionHeadingRenderData heading,
  }) : kind = RaplaListItemKind.sectionHeading,
       heading = heading,
       row = null;

  const RaplaListItem.eventRow({
    required this.stableKey,
    required this.sectionKey,
    required this.sectionKind,
    required ImportantEventAgendaRowRenderData row,
  }) : kind = RaplaListItemKind.eventRow,
       heading = null,
       row = row;
}

class DateEntryRenderData {
  final DateEntry entry;
  final String dateText;
  final String? timeText;
  final bool isPast;

  const DateEntryRenderData({
    required this.entry,
    required this.dateText,
    required this.timeText,
    required this.isPast,
  });

  factory DateEntryRenderData.prepare({
    required DateEntry entry,
    required DateFormat dateFormat,
    required DateFormat timeFormat,
    required DateTime now,
  }) {
    return DateEntryRenderData(
      entry: entry,
      dateText: dateFormat.format(entry.start),
      timeText: isAtMidnight(entry.start)
          ? null
          : timeFormat.format(entry.start),
      isPast: entry.end.isBefore(now),
    );
  }
}

class DateTableColumnWidths {
  static const double horizontalMargin = 24;
  static const double columnSpacing = 56;
  static const double dateColumnWidth = 120;

  final double description;
  final double date;

  const DateTableColumnWidths({required this.description, required this.date});

  factory DateTableColumnWidths.forAvailableWidth(double availableWidth) {
    final description = math.max(
      0,
      availableWidth - (horizontalMargin * 2) - columnSpacing - dateColumnWidth,
    );
    return DateTableColumnWidths(
      description: description.toDouble(),
      date: dateColumnWidth,
    );
  }
}
