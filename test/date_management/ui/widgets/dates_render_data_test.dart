import 'package:dualmate/date_management/model/date_entry.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:dualmate/date_management/ui/widgets/dates_render_data.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test('fully flattens sections with stable keys and an O(1) index map', () {
    final examWeek = _examWeek(
      _event('Klausurwoche', DateTime(2026, 7, 27), DateTime(2026, 7, 31)),
      <ImportantEvent>[
        _event(
          'Analysis',
          DateTime(2026, 7, 28, 9),
          DateTime(2026, 7, 28, 11),
          type: ScheduleEntryType.Exam,
        ),
      ],
    );
    final emptyExamWeek = _examWeek(
      _event('Klausurwoche 2', DateTime(2026, 9, 21), DateTime(2026, 9, 25)),
      const <ImportantEvent>[],
    );
    final renderData = _prepare([
      _standalone(
        _event('Holiday', DateTime(2026, 7, 1), DateTime(2026, 7, 1)),
      ),
      examWeek,
      emptyExamWeek,
    ]);

    expect(renderData.raplaItems.map((item) => item.kind), [
      RaplaListItemKind.eventRow,
      RaplaListItemKind.sectionHeading,
      RaplaListItemKind.eventRow,
      RaplaListItemKind.sectionHeading,
    ]);
    expect(
      renderData.raplaItems[1].sectionKind,
      ImportantEventSectionKind.examWeek,
    );
    expect(renderData.raplaItems[3].heading!.title, 'Klausurwoche 2');
    expect(
      renderData.raplaItems.map((item) => item.stableKey).toSet(),
      hasLength(renderData.raplaItems.length),
    );
    for (var index = 0; index < renderData.raplaItems.length; index++) {
      expect(
        renderData.raplaIndexByKey[renderData.raplaItems[index].stableKey],
        index,
      );
    }
  });

  test('prepares localized weekday month year and time fields', () {
    final event = _event(
      'Exam',
      DateTime(2026, 10, 7, 8, 5),
      DateTime(2026, 10, 7, 10),
      type: ScheduleEntryType.Exam,
    );

    final de = _prepare([
      _standalone(event),
    ], locale: 'de').raplaItems.single.row!;
    final en = _prepare([
      _standalone(event),
    ], locale: 'en').raplaItems.single.row!;

    expect(de.event.weekday, 'Mi');
    expect(de.event.startDay, '7');
    expect(de.event.startMonth, 'OKT');
    expect(de.event.startYear, isNull);
    expect(de.event.timeText, '08:05');
    expect(en.event.weekday, 'Wed');
    expect(en.event.startMonth, 'OCT');
  });

  test('shows a year outside the current calendar year', () {
    final row = _prepare([
      _standalone(_event('Future', DateTime(2027, 1, 2), DateTime(2027, 1, 2))),
    ]).raplaItems.single.row!;

    expect(row.event.startYear, '2027');
  });

  test('prepares literal same-month cross-month and cross-year ranges', () {
    final renderData = _prepare([
      _standalone(
        _event('Same month', DateTime(2026, 7, 27), DateTime(2026, 7, 31)),
      ),
      _standalone(
        _event('Cross month', DateTime(2026, 9, 28), DateTime(2026, 10, 2)),
      ),
      _standalone(
        _event('Cross year', DateTime(2026, 12, 30), DateTime(2027, 1, 2)),
      ),
    ]);
    final rows = renderData.raplaItems.map((item) => item.row!.event).toList();

    expect(rows[0].rangeStyle, ImportantEventRangeStyle.sameMonth);
    expect(rows[0].startDay, '27');
    expect(rows[0].endDay, '31');
    expect(rows[0].startMonth, 'JUL');
    expect(rows[0].endMonth, isNull);
    expect(rows[1].rangeStyle, ImportantEventRangeStyle.crossMonth);
    expect(rows[1].startDay, '28');
    expect(rows[1].endDay, '02');
    expect(rows[1].startMonth, 'SEP');
    expect(rows[1].endMonth, 'OCT');
    expect(rows[2].rangeStyle, ImportantEventRangeStyle.crossYear);
    expect(rows[2].startYear, '2026');
    expect(rows[2].endYear, '2027');
    expect(rows.every((row) => row.timeText == null), isTrue);
  });

  test('suppresses only immediately repeated single-day rails', () {
    final day = DateTime(2026, 7, 7);
    final renderData = _prepare([
      _standalone(_event('First', day, day.add(const Duration(hours: 1)))),
      _standalone(
        _event(
          'Second',
          day.add(const Duration(hours: 2)),
          day.add(const Duration(hours: 3)),
        ),
      ),
      _standalone(_event('Range', day, day.add(const Duration(days: 1)))),
      _standalone(
        _event(
          'After range',
          day.add(const Duration(hours: 4)),
          day.add(const Duration(hours: 5)),
        ),
      ),
      _examWeek(
        _event('Klausurwoche', day, day.add(const Duration(days: 4))),
        <ImportantEvent>[
          _event(
            'After heading',
            day.add(const Duration(hours: 6)),
            day.add(const Duration(hours: 7)),
            type: ScheduleEntryType.Exam,
          ),
        ],
      ),
    ]);
    final rows = renderData.raplaItems
        .where((item) => item.kind == RaplaListItemKind.eventRow)
        .map((item) => item.row!)
        .toList();

    expect(rows.map((row) => row.suppressDateRail), [
      false,
      true,
      false,
      false,
      false,
    ]);
    expect(rows.map((row) => row.spacingRole), [
      AgendaRowSpacingRole.first,
      AgendaRowSpacingRole.sameDayContinuation,
      AgendaRowSpacingRole.normalDateChange,
      AgendaRowSpacingRole.normalDateChange,
      AgendaRowSpacingRole.afterSectionHeading,
    ]);
  });

  test('resets section spacing after an empty exam week', () {
    final renderData = _prepare([
      _examWeek(
        _event(
          'Empty Klausurwoche',
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 5),
        ),
        const <ImportantEvent>[],
      ),
      _standalone(
        _event('Later event', DateTime(2026, 7, 14), DateTime(2026, 7, 14)),
      ),
    ]);

    expect(
      renderData.raplaItems.last.row!.spacingRole,
      AgendaRowSpacingRole.normalDateChange,
    );
  });

  test('adds a larger spacing role only for noticeable calendar gaps', () {
    final renderData = _prepare([
      _standalone(_event('First', DateTime(2026, 7, 1), DateTime(2026, 7, 1))),
      _standalone(_event('Nearby', DateTime(2026, 7, 4), DateTime(2026, 7, 4))),
      _standalone(
        _event('Distant', DateTime(2026, 7, 14), DateTime(2026, 7, 14)),
      ),
    ]);
    final rows = renderData.raplaItems.map((item) => item.row!).toList();

    expect(rows[1].spacingRole, AgendaRowSpacingRole.normalDateChange);
    expect(rows[2].spacingRole, AgendaRowSpacingRole.distantDateChange);
  });

  test('keeps a seven-day calendar gap across daylight-saving changes', () {
    final renderData = _prepare([
      _standalone(
        _event('Before DST', DateTime(2026, 3, 23), DateTime(2026, 3, 23)),
      ),
      _standalone(
        _event('After DST', DateTime(2026, 3, 30), DateTime(2026, 3, 30)),
      ),
    ]);

    expect(
      renderData.raplaItems.last.row!.spacingRole,
      AgendaRowSpacingRole.distantDateChange,
    );
  });

  test('preserves full content in localized semantics labels', () {
    const title = 'A very long exam title that must remain complete';
    const professor = 'Prof. Ada Lovelace and Prof. Grace Hopper';
    final event = _event(
      title,
      DateTime(2025, 7, 7, 8, 15),
      DateTime(2025, 7, 7, 10),
      type: ScheduleEntryType.Exam,
      professor: professor,
    );

    final row = _prepare([_standalone(event)]).raplaItems.single.row!;

    expect(row.event.semanticsLabel, contains(title));
    expect(row.event.semanticsLabel, contains(professor));
    expect(row.event.semanticsLabel, contains('08:15'));
    expect(row.event.semanticsLabel, contains('past'));
  });

  test('prepares exam-week range subtitle and heading semantics', () {
    final renderData = _prepare([
      _examWeek(
        _event('Klausurwoche', DateTime(2026, 7, 27), DateTime(2026, 7, 31)),
        const <ImportantEvent>[],
      ),
    ]);
    final heading = renderData.raplaItems.single.heading!;

    expect(heading.rangeSubtitle, '27–31 JUL');
    expect(heading.semanticsLabel, contains('Klausurwoche'));
    expect(heading.semanticsLabel, contains('July'));
  });

  test('keeps past-state scheduling and DH-Mine preparation intact', () {
    final event = _event(
      'Future',
      DateTime(2026, 2, 1, 8),
      DateTime(2026, 2, 1, 9),
    );
    final entry = DateEntry(
      description: 'Past date',
      year: '2026',
      comment: '',
      databaseName: 'Termine_BWL_Bank',
      start: DateTime(2025, 12, 1),
      end: DateTime(2025, 12, 1, 10),
      room: '',
    );
    final renderData = DatesRenderData.prepare(
      sections: [_standalone(event)],
      entries: [entry],
      locale: 'en',
      now: DateTime(2026, 1, 15),
    );

    expect(renderData.nextPastStateChange, DateTime(2026, 2, 1, 9));
    expect(renderData.dateEntries.single.dateText, '01/12/2025');
    expect(renderData.dateEntries.single.isPast, isTrue);
    expect(DateTableColumnWidths.forAvailableWidth(360).description, 136);
  });
}

DatesRenderData _prepare(
  List<ImportantEventSection> sections, {
  String locale = 'en',
}) {
  return DatesRenderData.prepare(
    sections: sections,
    entries: const <DateEntry>[],
    locale: locale,
    now: DateTime(2026, 1, 1),
  );
}

ImportantEventSection _standalone(ImportantEvent event) {
  return ImportantEventSection(
    kind: ImportantEventSectionKind.standalone,
    header: null,
    events: <ImportantEvent>[event],
  );
}

ImportantEventSection _examWeek(
  ImportantEvent header,
  List<ImportantEvent> events,
) {
  return ImportantEventSection(
    kind: ImportantEventSectionKind.examWeek,
    header: header,
    events: events,
  );
}

ImportantEvent _event(
  String title,
  DateTime start,
  DateTime end, {
  ScheduleEntryType type = ScheduleEntryType.SpecialEvent,
  String professor = '',
}) {
  return ImportantEvent(
    title: title,
    start: start,
    end: end,
    professor: professor,
    type: type,
  );
}
