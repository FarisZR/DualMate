import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/model/credentials.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/data/timetable_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/ui/customization/timetable_customization_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Preferences preferences;
  late _Timetables repository;
  late _Sources sources;
  late _Entries entries;
  late TimetableCustomizationViewModel model;
  final primary = _configuration('rapla:b4', ScheduleSourceType.Rapla, true);
  final additional = _configuration('ical:b6', ScheduleSourceType.Ical, false);
  final dualis = TimetableConfiguration(
    id: 'dualis:student',
    label: 'My class',
    type: ScheduleSourceType.Dualis,
    value: 'student',
    includeAll: true,
  );
  final credentials = Credentials('student', 'new-password');

  setUp(() async {
    preferences = _Preferences();
    repository = _Timetables(preferences, [primary, additional]);
    entries = _Entries();
    sources = _Sources(preferences, entries, repository);
    model = TimetableCustomizationViewModel(
      repository: repository,
      sourceProvider: sources,
      scheduleProvider: _ScheduleProvider(),
      entryRepository: entries,
    );
    await model.load();
  });
  tearDown(() => model.dispose());

  Future<void> configure() => model.put(
    dualis,
    replacingId: primary.id,
    dualisCredentials: credentials,
  );

  test(
    'preview keeps credentials and timetables unchanged until Save',
    () async {
      await configure();
      expect(sources.previewCredentials, same(credentials));
      expect(preferences.credentials.username, 'previous');
      expect(repository.configurations.first.id, primary.id);
      expect(model.sources.first.type, ScheduleSourceType.Dualis);
      expect(model.sources.last, same(additional));
      expect(model.modules[dualis.id], ['Math']);
      await model.save();
      expect(preferences.credentials, same(credentials));
      expect(repository.configurations.map((s) => s.id), [
        dualis.id,
        additional.id,
      ]);
      expect(repository.configurations.first.includes('Math'), isTrue);
      expect(repository.configurations.last.includes('Math'), isFalse);
      expect(entries.previews.single.entries.single.sourceIdentity, dualis.id);
    },
  );

  test('discarding a draft never writes Dualis credentials', () async {
    await configure();
    expect(preferences.writes, 0);
    expect(repository.configurations.first.id, primary.id);
  });

  test('failed preview preserves the active source and credentials', () async {
    sources.failPreview = true;
    await expectLater(
      configure(),
      throwsA(isA<ScheduleQueryFailedException>()),
    );
    expect(model.sources.first.id, primary.id);
    expect(model.dirty, isFalse);
    expect(model.loadingSource, isFalse);
    expect(preferences.writes, 0);
  });

  test(
    'failed configuration save restores previously stored credentials',
    () async {
      await configure();
      repository.failSave = true;
      await expectLater(model.save(), throwsStateError);
      expect(preferences.credentials.username, 'previous');
      expect(preferences.credentials.password, 'old-password');
      expect(repository.configurations.first.id, primary.id);
      expect(model.dirty, isTrue);
    },
  );

  test('changing only the password still validates the new login', () async {
    await configure();
    sources.failPreview = true;
    await expectLater(
      model.put(
        dualis,
        replacingId: dualis.id,
        dualisCredentials: Credentials('student', 'wrong-password'),
      ),
      throwsA(isA<ScheduleQueryFailedException>()),
    );
    expect(model.dualisCredentials.password, 'new-password');
    expect(preferences.writes, 0);
  });

  test(
    'removing a draft Dualis source does not save unused credentials',
    () async {
      await configure();
      model.remove(dualis);
      await model.save();
      expect(preferences.writes, 0);
      expect(repository.configurations, [additional]);
    },
  );
}

TimetableConfiguration _configuration(
  String id,
  ScheduleSourceType type,
  bool all,
) => TimetableConfiguration(
  id: id,
  label: id,
  type: type,
  value: 'https://example.com/$id',
  includeAll: all,
);

class _Preferences implements PreferencesProvider {
  Credentials credentials = Credentials('previous', 'old-password');
  int writes = 0;
  @override
  Future<Credentials> loadDualisCredentials() async => credentials;
  @override
  Future<void> storeDualisCredentials(Credentials value) async {
    credentials = value;
    writes++;
  }

  @override
  Future<bool> getPrettifySchedule() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Timetables implements TimetableRepository {
  @override
  final PreferencesProvider preferences;
  List<TimetableConfiguration> configurations;
  bool failSave = false;
  _Timetables(this.preferences, this.configurations);
  @override
  Future<List<TimetableConfiguration>> load() async => configurations;
  @override
  Future<TimetableSnapshot> loadSnapshot() async =>
      TimetableSnapshot(configurations, 1);
  @override
  Future<Map<String, List<String>>> moduleNames() async => {};
  @override
  Future<void> save(List<TimetableConfiguration> value) async {
    if (failSave) throw StateError('save failed');
    configurations = List.of(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sources extends ScheduleSourceProvider {
  Credentials? previewCredentials;
  bool failPreview = false;
  _Sources(_Preferences preferences, _Entries entries, _Timetables repository)
    : super(
        preferences,
        false,
        entries,
        _Queries(),
        timetableRepository: repository,
      );
  @override
  Future<ScheduleSource> createSource(
    TimetableConfiguration source, {
    Credentials? dualisCredentials,
  }) async {
    previewCredentials = dualisCredentials;
    return _Preview(failPreview);
  }
}

class _Preview implements ScheduleSource {
  final bool fail;
  _Preview(this.fail);
  @override
  bool canQuery() => true;
  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? token,
  ]) async {
    if (fail) throw ScheduleQueryFailedException(StateError('login failed'));
    return ScheduleQueryResult(
      Schedule()..addEntry(
        ScheduleEntry(
          title: 'Math',
          start: from,
          end: from.add(const Duration(hours: 1)),
          details: '',
          room: '',
          professor: '',
          type: ScheduleEntryType.Class,
        ),
      ),
      [],
    );
  }
}

class _Entries implements ScheduleEntryRepository {
  final List<Schedule> previews = [];
  @override
  Future<void> saveSchedule(Schedule schedule) async => previews.add(schedule);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Queries implements ScheduleQueryInformationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScheduleProvider implements ScheduleProvider {
  @override
  void invalidateScheduleCache() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
