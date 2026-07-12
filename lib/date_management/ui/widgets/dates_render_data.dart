import 'dart:math' as math;

import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/date_management/model/date_entry.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:intl/intl.dart';

/// Immutable, preformatted data consumed by the Dates list item builders.
///
/// Dates are often rebuilt because loading and pagination state changes. Keeping
/// formatting and past-state checks in this snapshot means visible rows only
/// construct text widgets and do not repeat the work for every build.
class DatesRenderData {
  static const int maxEagerRowsPerSection = 4;

  final List<RaplaListItem> raplaItems;
  final List<DateEntryRenderData> dateEntries;
  final DateTime? nextPastStateChange;

  DatesRenderData._({
    required this.raplaItems,
    required this.dateEntries,
    required this.nextPastStateChange,
  });

  factory DatesRenderData.prepare({
    required List<ImportantEventSection> sections,
    required List<DateEntry> entries,
    required String locale,
    required DateTime now,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy', locale);
    final timeFormat = DateFormat.Hm(locale);
    final eventDataByEvent = <ImportantEvent, ImportantEventRenderData>{};
    final renderedSections = <ImportantEventSectionRenderData>[];

    ImportantEventRenderData renderEvent(ImportantEvent event) {
      return eventDataByEvent.putIfAbsent(
        event,
        () => ImportantEventRenderData.prepare(
          event: event,
          dateFormat: dateFormat,
          timeFormat: timeFormat,
          now: now,
        ),
      );
    }

    for (final section in sections) {
      renderedSections.add(
        ImportantEventSectionRenderData(
          section: section,
          header: section.header == null ? null : renderEvent(section.header!),
          events: List<ImportantEventRenderData>.unmodifiable(
            section.events.map(renderEvent),
          ),
          isExamSection: _isExamSection(section),
        ),
      );
    }

    final raplaItems = <RaplaListItem>[];
    for (
      var sectionIndex = 0;
      sectionIndex < renderedSections.length;
      sectionIndex++
    ) {
      final section = renderedSections[sectionIndex];
      final sectionRows = <_SectionRow>[];

      if (section.header != null) {
        sectionRows.add(_SectionRow(data: section.header!, isHeader: true));
      }
      sectionRows.addAll(
        section.events.map(
          (event) => _SectionRow(data: event, isHeader: false),
        ),
      );

      if (sectionRows.length <= maxEagerRowsPerSection) {
        raplaItems.add(
          RaplaListItem.section(section: section, sectionIndex: sectionIndex),
        );
        continue;
      }

      for (var rowIndex = 0; rowIndex < sectionRows.length; rowIndex++) {
        final row = sectionRows[rowIndex];
        final isFirst = rowIndex == 0;
        final isLast = rowIndex == sectionRows.length - 1;
        raplaItems.add(
          RaplaListItem.row(
            data: row.data,
            sectionIndex: sectionIndex,
            rowIndex: rowIndex,
            position: _positionFor(isFirst, isLast),
            isHeader: row.isHeader,
            showDividerAfter: row.isHeader && !isLast,
            isExamSection: section.isExamSection,
          ),
        );
      }
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
      dateEntries: dateEntries,
      nextPastStateChange: nextPastStateChange,
    );
  }

  static ImportantEventRowPosition _positionFor(bool isFirst, bool isLast) {
    if (isFirst && isLast) return ImportantEventRowPosition.single;
    if (isFirst) return ImportantEventRowPosition.top;
    if (isLast) return ImportantEventRowPosition.bottom;
    return ImportantEventRowPosition.middle;
  }

  static bool _isExamSection(ImportantEventSection section) {
    if (section.events.any((event) => event.type == ScheduleEntryType.Exam)) {
      return true;
    }

    final title = section.header?.title.toLowerCase() ?? '';
    return title.contains('klausur');
  }
}

class ImportantEventRenderData {
  final ImportantEvent event;
  final String dateText;
  final bool isPast;

  const ImportantEventRenderData({
    required this.event,
    required this.dateText,
    required this.isPast,
  });

  factory ImportantEventRenderData.prepare({
    required ImportantEvent event,
    required DateFormat dateFormat,
    required DateFormat timeFormat,
    required DateTime now,
  }) {
    var dateText = dateFormat.format(event.start);
    if (event.isSingleDay) {
      if (event.hasTime) {
        dateText = '$dateText · ${timeFormat.format(event.start)}';
      }
    } else {
      dateText = '$dateText - ${dateFormat.format(event.end)}';
    }

    return ImportantEventRenderData(
      event: event,
      dateText: dateText,
      isPast: event.end.isBefore(now),
    );
  }
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

class ImportantEventSectionRenderData {
  final ImportantEventSection section;
  final ImportantEventRenderData? header;
  final List<ImportantEventRenderData> events;
  final bool isExamSection;

  const ImportantEventSectionRenderData({
    required this.section,
    required this.header,
    required this.events,
    required this.isExamSection,
  });
}

enum ImportantEventRowPosition { single, top, middle, bottom }

class RaplaListItem {
  final ImportantEventSectionRenderData? section;
  final ImportantEventRenderData? data;
  final int sectionIndex;
  final int rowIndex;
  final ImportantEventRowPosition position;
  final bool isHeader;
  final bool showDividerAfter;
  final bool isExamSection;

  RaplaListItem.section({
    required ImportantEventSectionRenderData section,
    required this.sectionIndex,
  }) : section = section,
       data = null,
       rowIndex = 0,
       position = ImportantEventRowPosition.single,
       isHeader = false,
       showDividerAfter = false,
       isExamSection = section.isExamSection;

  const RaplaListItem.row({
    required ImportantEventRenderData data,
    required this.sectionIndex,
    required this.rowIndex,
    required this.position,
    required this.isHeader,
    required this.showDividerAfter,
    required this.isExamSection,
  }) : section = null,
       data = data;

  bool get isSection => section != null;
}

class _SectionRow {
  final ImportantEventRenderData data;
  final bool isHeader;

  const _SectionRow({required this.data, required this.isHeader});
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
