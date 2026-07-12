import 'package:dualmate/date_management/model/date_entry.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:dualmate/date_management/ui/widgets/dates_render_data.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  test('preformats dates and past state in one render snapshot', () {
    final event = ImportantEvent(
      title: 'Exam',
      start: DateTime(2026, 1, 2, 8),
      end: DateTime(2026, 1, 2, 10),
      type: ScheduleEntryType.Exam,
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
      sections: [
        ImportantEventSection(header: null, events: [event]),
      ],
      entries: [entry],
      locale: 'en',
      now: DateTime(2026, 1, 1),
    );

    final compactSection = renderData.raplaItems.single.section!;
    expect(compactSection.events.single.dateText, '02/01/2026 · 08:00');
    expect(compactSection.events.single.isPast, isFalse);
    expect(renderData.dateEntries.single.dateText, '01/12/2025');
    expect(renderData.dateEntries.single.timeText, isNull);
    expect(renderData.dateEntries.single.isPast, isTrue);
  });

  test('flattens grouped sections with row positions', () {
    final section = ImportantEventSection(
      header: ImportantEvent(
        title: 'Klausurwoche',
        start: DateTime(2026, 2, 1),
        end: DateTime(2026, 2, 5),
        type: ScheduleEntryType.SpecialEvent,
      ),
      events: [
        ImportantEvent(
          title: 'Exam 1',
          start: DateTime(2026, 2, 2, 8),
          end: DateTime(2026, 2, 2, 10),
          type: ScheduleEntryType.Exam,
        ),
        ImportantEvent(
          title: 'Exam 2',
          start: DateTime(2026, 2, 3, 8),
          end: DateTime(2026, 2, 3, 10),
          type: ScheduleEntryType.Exam,
        ),
        ImportantEvent(
          title: 'Exam 3',
          start: DateTime(2026, 2, 4, 8),
          end: DateTime(2026, 2, 4, 10),
          type: ScheduleEntryType.Exam,
        ),
        ImportantEvent(
          title: 'Exam 4',
          start: DateTime(2026, 2, 5, 8),
          end: DateTime(2026, 2, 5, 10),
          type: ScheduleEntryType.Exam,
        ),
      ],
    );

    final renderData = DatesRenderData.prepare(
      sections: [section],
      entries: const [],
      locale: 'en',
      now: DateTime(2026, 1, 1),
    );

    expect(renderData.raplaItems, hasLength(5));
    expect(renderData.raplaItems.map((item) => item.position), [
      ImportantEventRowPosition.top,
      ImportantEventRowPosition.middle,
      ImportantEventRowPosition.middle,
      ImportantEventRowPosition.middle,
      ImportantEventRowPosition.bottom,
    ]);
    expect(renderData.raplaItems.first.isHeader, isTrue);
    expect(renderData.raplaItems.first.showDividerAfter, isTrue);
    expect(renderData.raplaItems.every((item) => item.isExamSection), isTrue);
    expect(renderData.raplaItems.every((item) => !item.isSection), isTrue);
  });

  test('keeps small sections as one card item', () {
    final event = ImportantEvent(
      title: 'Holiday',
      start: DateTime(2026, 2, 2),
      end: DateTime(2026, 2, 2),
      type: ScheduleEntryType.PublicHoliday,
    );

    final renderData = DatesRenderData.prepare(
      sections: [
        ImportantEventSection(header: null, events: [event]),
      ],
      entries: const [],
      locale: 'en',
      now: DateTime(2026, 1, 1),
    );

    expect(renderData.raplaItems, hasLength(1));
    expect(renderData.raplaItems.single.isSection, isTrue);
    expect(renderData.raplaItems.single.section!.events.single.event, event);
  });

  test('computes fixed table widths once for the viewport', () {
    final widths = DateTableColumnWidths.forAvailableWidth(360);

    expect(widths.date, DateTableColumnWidths.dateColumnWidth);
    expect(widths.description, 136);
  });
}
