import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:test/test.dart';

void main() {
  test('WidgetScheduleEntryPayload parses map values', () {
    final start = DateTime(2026, 1, 27, 8, 0);
    final end = DateTime(2026, 1, 27, 9, 0);
    final payload = WidgetScheduleEntryPayload.fromMap({
      widgetScheduleEntryId: 12,
      widgetScheduleEntryStart: start.millisecondsSinceEpoch,
      widgetScheduleEntryEnd: end.millisecondsSinceEpoch,
      widgetScheduleEntryTitle: 'Math',
      widgetScheduleEntryDetails: 'Room 201',
      widgetScheduleEntryProfessor: 'Prof. A',
      widgetScheduleEntryRoom: '201',
      widgetScheduleEntryType: ScheduleEntryType.Class.index,
      widgetScheduleDayStart: start.millisecondsSinceEpoch,
    });

    expect(payload.id, 12);
    expect(payload.start, start);
    expect(payload.end, end);
    expect(payload.title, 'Math');
    expect(payload.details, 'Room 201');
    expect(payload.professor, 'Prof. A');
    expect(payload.room, '201');
    expect(payload.type, ScheduleEntryType.Class.index);
    expect(payload.dayStart, start);
  });

  test('resolveScheduleEntry uses id with fallback', () {
    final first = ScheduleEntry(
      id: 1,
      start: DateTime(2026, 1, 27, 8, 0),
      end: DateTime(2026, 1, 27, 9, 0),
      title: 'Math',
      details: 'Room 201',
      professor: 'Prof. A',
      room: '201',
      type: ScheduleEntryType.Class,
    );
    final second = ScheduleEntry(
      id: 2,
      start: DateTime(2026, 1, 27, 10, 0),
      end: DateTime(2026, 1, 27, 11, 0),
      title: 'Physics',
      details: 'Room 202',
      professor: 'Prof. B',
      room: '202',
      type: ScheduleEntryType.Class,
    );

    final idPayload = WidgetScheduleEntryPayload(id: 2);
    final idMatch = resolveScheduleEntry([first, second], idPayload);
    expect(idMatch, second);

    final fallbackPayload = WidgetScheduleEntryPayload(
      id: 99,
      start: first.start,
      end: first.end,
      title: first.title,
      details: first.details,
      professor: first.professor,
      room: first.room,
      type: first.type.index,
    );
    final fallbackMatch =
        resolveScheduleEntry([first, second], fallbackPayload);
    expect(fallbackMatch, first);
  });

  test('resolveScheduleEntry returns null without match data', () {
    final entry = ScheduleEntry(
      id: 1,
      start: DateTime(2026, 1, 27, 8, 0),
      end: DateTime(2026, 1, 27, 9, 0),
      title: 'Math',
      details: 'Room 201',
      professor: 'Prof. A',
      room: '201',
      type: ScheduleEntryType.Class,
    );

    final payload = WidgetScheduleEntryPayload();
    final match = resolveScheduleEntry([entry], payload);
    expect(match, isNull);
  });

  test('WidgetCanteenDayPayload parses day start', () {
    final dayStart = DateTime(2026, 2, 6);
    final payload = WidgetCanteenDayPayload.fromMap({
      widgetCanteenDayStart: dayStart.millisecondsSinceEpoch,
    });

    expect(payload.dayStart, dayStart);
  });
}
