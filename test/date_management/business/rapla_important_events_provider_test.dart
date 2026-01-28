import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/date_management/business/rapla_important_events_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:test/test.dart';

class FakePreferencesAccess extends PreferencesAccess {
  final Map<String, Object?> _values = {};

  @override
  Future<void> set<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  Future<T?> get<T>(String key) async {
    return _values[key] as T?;
  }
}

class FakeSecureStorageAccess extends SecureStorageAccess {
  final Map<String, String> _values = {};

  @override
  Future<String?> get(String key) async {
    return _values[key];
  }

  @override
  Future<void> set(String key, String value) async {
    _values[key] = value;
  }
}

void main() {
  test('Filters only important entry types', () {
    var schedule = Schedule.fromList([
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 8),
        end: DateTime(2026, 7, 27, 9),
        title: 'Lecture',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.Class,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 9),
        end: DateTime(2026, 7, 27, 10),
        title: 'Exam',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.Exam,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 28, 8),
        end: DateTime(2026, 7, 28, 9),
        title: 'Holiday',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.PublicHoliday,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 29, 8),
        end: DateTime(2026, 7, 29, 9),
        title: 'Test Week',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
    ]);

    var filtered =
        RaplaImportantEventsProvider.filterImportantEntries(schedule);

    expect(filtered.length, 3);
    expect(
      filtered.any((entry) => entry.type == ScheduleEntryType.Class),
      false,
    );
  });

  test('Merges consecutive same-title events', () {
    var entries = [
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 7),
        end: DateTime(2026, 7, 27, 8),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 28, 7),
        end: DateTime(2026, 7, 28, 8),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 29, 7),
        end: DateTime(2026, 7, 29, 8),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
    ];

    var merged = RaplaImportantEventsProvider.mergeImportantEntries(entries);

    expect(merged.length, 1);
    expect(merged.first.start, DateTime(2026, 7, 27, 7));
    expect(merged.first.end, DateTime(2026, 7, 29, 8));
  });

  test('Keeps separate events when there is a gap', () {
    var entries = [
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 7),
        end: DateTime(2026, 7, 27, 8),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 29, 7),
        end: DateTime(2026, 7, 29, 8),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
    ];

    var merged = RaplaImportantEventsProvider.mergeImportantEntries(entries);

    expect(merged.length, 2);
  });

  test('Does not merge exams across days', () {
    var entries = [
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 7),
        end: DateTime(2026, 7, 27, 8),
        title: 'Klausur',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.Exam,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 28, 7),
        end: DateTime(2026, 7, 28, 8),
        title: 'Klausur',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.Exam,
      ),
    ];

    var merged = RaplaImportantEventsProvider.mergeImportantEntries(entries);

    expect(merged.length, 2);
  });

  test('Deduplicates identical entries', () {
    var schedule = Schedule.fromList([
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 9),
        end: DateTime(2026, 7, 27, 10),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 9),
        end: DateTime(2026, 7, 27, 10),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
    ]);

    var filtered =
        RaplaImportantEventsProvider.filterImportantEntries(schedule);

    expect(filtered.length, 1);
  });
}

PreferencesProvider _buildPreferencesProvider() {
  return PreferencesProvider(
      FakePreferencesAccess(), FakeSecureStorageAccess());
}
