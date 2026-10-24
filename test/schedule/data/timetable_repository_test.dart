import 'dart:convert';
import 'dart:io';

import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/data/sql_scripts.dart';
import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/schedule/business/schedule_filter.dart';
import 'package:dualmate/schedule/business/schedule_source_identity.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/data/timetable_repository.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:dualmate/schedule/reminders/class_reminder_repository.dart';
import 'package:dualmate/schedule/reminders/class_reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late DatabaseAccess access;
  late PreferencesProvider preferences;
  const url = 'https://rapla.example/rapla?page=calendar&file=B4&user=test';
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    access = DatabaseAccess(database: db);
    for (final migration in SqlScripts.databaseMigrationScripts.take(5)) {
      for (final statement in migration) {
        await db.execute(statement);
      }
    }
    await db.insert('ScheduleEntryFilters', {'title': 'Math'});
    await db.insert('ScheduleEntries', {
      'title': 'Math',
      'start': 1,
      'end': 2,
      'type': 1,
    });
    for (final statement in SqlScripts.databaseMigrationScripts[5]) {
      await db.execute(statement);
    }
    SharedPreferences.setMockInitialValues({
      PreferencesProvider.ScheduleSourceType: ScheduleSourceType.Rapla.index,
      PreferencesProvider.RaplaUrlKey: url,
    });
    preferences = PreferencesProvider(
      PreferencesAccess(),
      SecureStorageAccess(),
    );
  });
  tearDown(() => db.close());

  test(
    'same-name reminders stay source scoped and hidden alarms are cancelled',
    () async {
      final repository = TimetableRepository(access, preferences);
      final primary = (await repository.load()).single.withModule('Math', true);
      final additional = TimetableConfiguration(
        id: 'ical:b6',
        label: 'B6',
        type: ScheduleSourceType.Ical,
        value: 'https://example.com/b6.ics',
        exceptions: {'Math'},
      );
      final entries = ScheduleEntryRepository(access);
      final information = ScheduleQueryInformationRepository(access);
      final sources = ScheduleSourceProvider(
        preferences,
        true,
        entries,
        information,
        timetableRepository: repository,
      );
      await sources.saveTimetables([primary, additional]);
      final provider = ScheduleProvider(
        sources,
        entries,
        information,
        preferences,
        ScheduleFilterRepository(access),
        timetables: repository,
      );
      sources.addDidChangeScheduleSourceCallback(
        (_, __) => provider.invalidateScheduleCache(),
      );
      final now = DateTime(2026, 10, 23, 8);
      final lessons = [
        for (final source in [primary, additional])
          ScheduleEntry(
            sourceIdentity: source.id,
            title: 'Math',
            start: now.add(const Duration(hours: 2)),
            end: now.add(const Duration(hours: 3)),
            details: '',
            professor: '',
            room: '',
            type: ScheduleEntryType.Class,
          ),
      ];
      await entries.saveSchedule(Schedule.fromList(lessons));
      final scheduler = _Scheduler();
      final rules = ClassReminderRepository(access);
      final controller = ClassReminderController(
        repository: rules,
        scheduleProvider: provider,
        sourceProvider: sources,
        scheduler: scheduler,
        notificationApi: () => _GrantedNotifications(),
        now: () => now,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      for (final entry in lessons) {
        await controller.saveReminder(
          entry: entry,
          offset: const Duration(minutes: 10),
          scope: ClassReminderScope.recurring,
        );
      }
      await controller.queue.drain();
      expect(scheduler.active, hasLength(2));
      expect(controller.ruleFor(lessons.first)!.sourceIdentity, primary.id);
      expect(controller.ruleFor(lessons.last)!.sourceIdentity, additional.id);
      await sources.saveTimetables([
        primary.withModule('Math', false),
        additional,
      ]);
      await controller.waitForSourceChange();
      await controller.queue.drain();
      expect(scheduler.active, hasLength(1));
      expect(scheduler.cancelled, hasLength(1));
      expect(
        await rules.loadRelevantRules(sourceIdentity: primary.id, now: now),
        hasLength(1),
        reason: 'a hidden recurring rule remains available when reselected',
      );
      await sources.saveTimetables([additional]);
      await controller.waitForSourceChange();
      await controller.queue.drain();
      expect(
        await rules.loadRelevantRules(sourceIdentity: primary.id, now: now),
        isEmpty,
      );
      expect(scheduler.active, hasLength(1));
    },
  );

  test(
    'obsolete background writes are rejected after a selection change',
    () async {
      final repository = TimetableRepository(access, preferences);
      final primary = (await repository.load()).single;
      final revision = await repository.currentRevision();
      await repository.save([primary.withModule('Math', true)]);
      await expectLater(
        repository.persistSchedule(
          Schedule(),
          DateTime(2026),
          DateTime(2027),
          revision,
        ),
        throwsA(isA<OperationCancelledException>()),
      );
      expect(await db.query('ScheduleEntries'), hasLength(1));
    },
  );

  test('notification diffs respect selections and ignore configuration-only changes', () async {
    final repository = TimetableRepository(access, preferences);
    final primary = (await repository.load()).single;
    final entries = ScheduleEntryRepository(access);
    final information = ScheduleQueryInformationRepository(access);
    final sources = ScheduleSourceProvider(
      preferences,
      true,
      entries,
      information,
      timetableRepository: repository,
    );
    await sources.setupScheduleSource();
    final remote = _MutableSource(primary.id);
    sources.usePerformanceFixtureSource(remote);
    final provider = ScheduleProvider(
      sources,
      entries,
      information,
      preferences,
      ScheduleFilterRepository(access),
      timetables: repository,
    );
    final changed = <String>[];
    provider.addScheduleEntryChangedCallback((diff, _) async {
      changed.addAll(diff.addedEntries.map((e) => e.title));
      changed.addAll(diff.removedEntries.map((e) => e.title));
      changed.addAll(diff.updatedEntries.map((e) => e.entry.title));
    });
    final start = DateTime(2026, 10, 23);
    final end = start.add(const Duration(days: 14));
    await provider.getUpdatedSchedule(
      start,
      end,
      CancellationToken(),
      origin: ScheduleRefreshOrigin.backgroundPeriodic,
    );
    expect(changed, isEmpty, reason: 'first fetch establishes a baseline');
    remote.names = ['Math', 'Visible', 'Math'];
    await provider.getUpdatedSchedule(
      start,
      end,
      CancellationToken(),
      origin: ScheduleRefreshOrigin.backgroundPeriodic,
    );
    expect(changed, isEmpty, reason: 'hidden-only additions stay silent');
    remote.names.add('Added visible');
    await provider.getUpdatedSchedule(
      start,
      end,
      CancellationToken(),
      origin: ScheduleRefreshOrigin.backgroundPeriodic,
    );
    expect(changed, ['Added visible']);
    changed.clear();
    remote.names.addAll(['Math', 'Mixed visible']);
    await provider.getUpdatedSchedule(
      start,
      end,
      CancellationToken(),
      origin: ScheduleRefreshOrigin.backgroundPeriodic,
    );
    expect(changed, [
      'Mixed visible',
    ], reason: 'mixed updates mention only visible lessons');
    changed.clear();
    await sources.saveTimetables([
      primary.withModule('Math', true).withModule('Visible', false),
    ]);
    sources.usePerformanceFixtureSource(remote);
    await provider.getUpdatedSchedule(
      start,
      end,
      CancellationToken(),
      origin: ScheduleRefreshOrigin.backgroundPeriodic,
    );
    expect(
      changed,
      isEmpty,
      reason: 'both snapshots use the same current selections',
    );
  });

  test(
    'version 5 upgrade keeps the source, cached lessons and hidden modules',
    () async {
      final repository = TimetableRepository(access, preferences);
      final source = (await repository.load()).single;
      expect(
        source.id,
        ScheduleSourceIdentity.create(ScheduleSourceType.Rapla, url),
      );
      expect(source.label, 'B4');
      expect(source.includes('Math'), isFalse);
      expect(source.includes('New module'), isTrue);
      expect(
        (await db.query('ScheduleEntries')).single['sourceIdentity'],
        source.id,
      );
      expect(
        (await TimetableRepository(
          access,
          preferences,
        ).load()).single.exceptions,
        {'Math'},
      );
    },
  );

  test('source scoped selections agree with the native widget query and survive restart', () async {
    final repository = TimetableRepository(access, preferences);
    final primary = (await repository.load()).single;
    final additional = TimetableConfiguration(
      id: 'ical:b6',
      label: 'B6',
      type: ScheduleSourceType.Ical,
      value: 'https://example.com/b6.ics',
      exceptions: {'Math'},
    );
    await repository.save([primary, additional]);
    await db.insert('ScheduleEntries', {
      'sourceIdentity': additional.id,
      'title': 'Math',
      'start': 1,
      'end': 2,
      'type': 1,
    });
    await db.insert('ScheduleEntries', {
      'sourceIdentity': additional.id,
      'title': 'New module',
      'start': 1,
      'end': 2,
      'type': 1,
    });
    final schedule = await ScheduleEntryRepository(access)
        .queryScheduleBetweenDates(
          DateTime.fromMillisecondsSinceEpoch(0),
          DateTime.fromMillisecondsSinceEpoch(3),
        );
    final filtered = await ScheduleFilter(
      ScheduleFilterRepository(access),
      timetables: repository,
    ).filter(schedule);
    expect(filtered.entries.map((e) => '${e.sourceIdentity}/${e.title}'), [
      'ical:b6/Math',
    ]);
    // Execute the widget's actual Kotlin SQL so Flutter and native filtering
    // cannot silently diverge through a separately maintained test query.
    final kotlin = File(
      'android/app/src/main/kotlin/com/fariszr/dualmate/database/ScheduleProvider.kt',
    ).readAsStringSync();
    final constant = kotlin
        .split('private const val SCHEDULE_ENTRIES_BETWEEN_SQL =')
        .last;
    final sql = RegExp(r'"(?:[^"\\]|\\.)*"')
        .allMatches(constant)
        .map((match) => jsonDecode(match.group(0)!) as String)
        .join();
    final native = await db.rawQuery(sql, [0, 3]);
    expect(native, hasLength(1));
    expect(native.single['id'], filtered.entries.single.id);
    final restarted = await TimetableRepository(access, preferences).load();
    expect(restarted[1].includes('Math'), isTrue);
    expect(restarted[1].includes('New module'), isFalse);
    await repository.save([primary]);
    expect((await db.query('ScheduleEntries')).length, 1);
    await repository.save([]);
    expect(await TimetableRepository(access, preferences).load(), isEmpty);
  });
}

class _MutableSource implements ScheduleSource {
  final String id;
  List<String> names = ['Math', 'Visible'];
  _MutableSource(this.id);
  @override
  bool canQuery() => true;
  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? token,
  ]) async => ScheduleQueryResult(
    Schedule.fromList([
      for (var i = 0; i < names.length; i++)
        ScheduleEntry(
          sourceIdentity: id,
          title: names[i],
          start: from.add(Duration(hours: 9 + i)),
          end: from.add(Duration(hours: 10 + i)),
          details: '',
          professor: '',
          room: '',
          type: ScheduleEntryType.Class,
        ),
    ]),
    [],
  );
}

class _Scheduler implements ClassReminderScheduler {
  final Set<int> active = {};
  final List<int> cancelled = [];
  @override
  Future<void> schedule(ClassReminderNotificationRequest request) async {
    active.add(request.notificationId);
  }

  @override
  Future<void> cancel(int id) async {
    active.remove(id);
    cancelled.add(id);
  }
}

class _GrantedNotifications extends VoidNotificationApi {
  @override
  Future<bool> areNotificationsEnabled() async => true;
  @override
  Future<bool> areClassRemindersEnabled() async => true;
  @override
  Future<bool> canScheduleExactNotifications() async => true;
}
