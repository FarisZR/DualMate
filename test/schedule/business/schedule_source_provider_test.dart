import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('clearScheduleCache', () {
    test('deletes entries and query information', () async {
      final entryRepo = _RecordingEntryRepository();
      final queryRepo = _RecordingQueryInformationRepository();
      final provider = ScheduleSourceProvider(
        _FakePreferencesProvider(),
        false,
        entryRepo,
        queryRepo,
      );

      await provider.clearScheduleCache();

      expect(entryRepo.deleteAllCalls, 1);
      expect(queryRepo.deleteAllCalls, 1);
    });
  });
}

class _FakePreferencesProvider implements PreferencesProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _RecordingEntryRepository implements ScheduleEntryRepository {
  int deleteAllCalls = 0;

  @override
  Future<void> deleteAllScheduleEntries() async {
    deleteAllCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _RecordingQueryInformationRepository
    implements ScheduleQueryInformationRepository {
  int deleteAllCalls = 0;

  @override
  Future<void> deleteAllQueryInformation() async {
    deleteAllCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
