import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/service/error_report_schedule_source_decorator.dart';
import 'package:dualmate/schedule/service/invalid_schedule_source.dart';
import 'package:dualmate/schedule/service/mannheim/mannheim_course_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('setupForMannheim stores profile and generated iCal URL', () async {
    final preferencesProvider = _preferencesProvider();
    final entryRepository = _FakeScheduleEntryRepository();
    final queryRepository = _FakeScheduleQueryInformationRepository();
    final sourceProvider = ScheduleSourceProvider(
      preferencesProvider,
      true,
      entryRepository,
      queryRepository,
    );
    final course = MannheimCourse.fromProfileName('WWI23A');

    await sourceProvider.setupForMannheim(course);

    expect(await preferencesProvider.getMannheimScheduleId(), 'WWI23A');
    expect(
      await preferencesProvider.getIcalUrl(),
      'https://vorlesungsplan.stuvma.de/profiles/WWI23A',
    );
    expect(
      await preferencesProvider.getScheduleSourceType(),
      ScheduleSourceType.Mannheim.index,
    );
    expect(
      sourceProvider.currentScheduleSourceType,
      ScheduleSourceType.Mannheim,
    );
    expect(sourceProvider.currentScheduleSource.canQuery(), isTrue);
    expect(
      sourceProvider.currentScheduleSource,
      isA<ErrorReportScheduleSourceDecorator>(),
    );
    expect(entryRepository.deleteAllCalls, 1);
    expect(queryRepository.deleteAllCalls, 1);
  });

  test('Mannheim setup stores safely generated profile URLs', () async {
    final preferencesProvider = _preferencesProvider();
    final sourceProvider = ScheduleSourceProvider(
      preferencesProvider,
      true,
      _FakeScheduleEntryRepository(),
      _FakeScheduleQueryInformationRepository(),
    );
    final course = MannheimCourse.fromProfileName('IP/International Program');

    await sourceProvider.setupForMannheim(course);

    expect(
      await preferencesProvider.getIcalUrl(),
      'https://vorlesungsplan.stuvma.de/profiles/IP%2FInternational%20Program',
    );
  });

  test('stored Mannheim source delegates to the iCal runtime setup', () async {
    final preferencesProvider = _preferencesProvider();
    await preferencesProvider.setScheduleSourceType(
      ScheduleSourceType.Mannheim.index,
    );
    await preferencesProvider.setIcalUrl(
      'https://vorlesungsplan.stuvma.de/profiles/WWI23A',
    );
    final sourceProvider = ScheduleSourceProvider(
      preferencesProvider,
      true,
      _FakeScheduleEntryRepository(),
      _FakeScheduleQueryInformationRepository(),
    );

    final setupSucceeded = await sourceProvider.setupScheduleSource();

    expect(setupSucceeded, isTrue);
    expect(
      sourceProvider.currentScheduleSourceType,
      ScheduleSourceType.Mannheim,
    );
    expect(
      sourceProvider.currentScheduleSource,
      isA<ErrorReportScheduleSourceDecorator>(),
    );
    expect(sourceProvider.currentScheduleSource.canQuery(), isTrue);
  });

  test(
    'stale Mannheim configuration with a non-StuV URL is setup-required',
    () async {
      final preferencesProvider = _preferencesProvider();
      await preferencesProvider.setScheduleSourceType(
        ScheduleSourceType.Mannheim.index,
      );
      await preferencesProvider.setMannheimScheduleId('7201001');
      await preferencesProvider.setIcalUrl(
        'https://legacy.invalid/ical.php?uid=7201001',
      );
      final sourceProvider = ScheduleSourceProvider(
        preferencesProvider,
        true,
        _FakeScheduleEntryRepository(),
        _FakeScheduleQueryInformationRepository(),
      );

      final setupSucceeded = await sourceProvider.setupScheduleSource();

      expect(setupSucceeded, isFalse);
      expect(sourceProvider.currentScheduleSourceType, ScheduleSourceType.None);
      expect(
        sourceProvider.currentScheduleSource,
        isA<InvalidScheduleSource>(),
      );
    },
  );
}

PreferencesProvider _preferencesProvider() {
  return PreferencesProvider(PreferencesAccess(), SecureStorageAccess());
}

class _FakeScheduleEntryRepository implements ScheduleEntryRepository {
  int deleteAllCalls = 0;

  @override
  Future<void> deleteAllScheduleEntries() async {
    deleteAllCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleEntryRepository call: $invocation',
    );
  }
}

class _FakeScheduleQueryInformationRepository
    implements ScheduleQueryInformationRepository {
  int deleteAllCalls = 0;

  @override
  Future<void> deleteAllQueryInformation() async {
    deleteAllCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleQueryInformationRepository call: $invocation',
    );
  }
}
