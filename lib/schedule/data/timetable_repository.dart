import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_identity.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/data/schedule_entry_entity.dart';

class TimetableSnapshot {
  final List<TimetableConfiguration> sources;
  final int revision;
  TimetableSnapshot(this.sources, this.revision);
}

class TimetableRepository {
  final DatabaseAccess database;
  final PreferencesProvider preferences;
  TimetableRepository(this.database, this.preferences);

  Future<int> currentRevision() async =>
      (await database.queryRows('TimetableConfigurationState'))
              .first['revision']
          as int;

  /// Checking the persisted revision inside the write transaction also rejects
  /// refreshes from a background isolate running an obsolete configuration.
  Future<void> persistSchedule(
    Schedule schedule,
    DateTime start,
    DateTime end,
    int revision,
  ) async {
    await database.transaction((tx) async {
      final state = await tx.query('TimetableConfigurationState');
      if (state.single['revision'] != revision)
        throw OperationCancelledException();
      await tx.delete(
        'ScheduleEntries',
        where: 'start>=? AND end<=?',
        whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      );
      for (final entry in schedule.entries) {
        final row = ScheduleEntryEntity.fromModel(entry).toMap()..['id'] = null;
        entry.id = await tx.insert('ScheduleEntries', row);
      }
      await tx.rawInsert(
        'INSERT OR REPLACE INTO ScheduleQueryInformation(start,end,queryTime) VALUES(?,?,?)',
        [
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
    });
  }

  Future<List<TimetableConfiguration>> load() async =>
      (await loadSnapshot()).sources;

  Future<TimetableSnapshot> loadSnapshot() async {
    if ((await database.queryRows('TimetableConfigurationState')).isEmpty) {
      await _migrateLegacy();
    }
    return database.transaction((tx) async {
      final rows = await tx.query('TimetableSources', orderBy: 'position');
      final selections = await tx.query('TimetableModuleSelections');
      final state = await tx.query('TimetableConfigurationState');
      final sources = rows
          .map(
            (row) => TimetableConfiguration(
              id: row['id'] as String,
              label: row['label'] as String,
              type: ScheduleSourceType.values[row['type'] as int],
              value: row['value'] as String,
              includeAll: row['includeAll'] == 1,
              exceptions: selections
                  .where((s) => s['sourceIdentity'] == row['id'])
                  .map((s) => s['title'] as String)
                  .toSet(),
            ),
          )
          .toList();
      return TimetableSnapshot(sources, state.single['revision'] as int);
    });
  }

  Future<void> _migrateLegacy() async {
    final type =
        ScheduleSourceType.values[await preferences.getScheduleSourceType()];
    final value = switch (type) {
      ScheduleSourceType.Rapla => await preferences.getRaplaUrl(),
      ScheduleSourceType.Ical ||
      ScheduleSourceType.Mannheim => await preferences.getIcalUrl(),
      ScheduleSourceType.Dualis =>
        (await preferences.loadDualisCredentials()).username,
      ScheduleSourceType.None => '',
    };
    final identityValue = type == ScheduleSourceType.Mannheim
        ? await preferences.getMannheimScheduleId()
        : value;
    final hidden = await database.queryRows('ScheduleEntryFilters');
    final primary = type == ScheduleSourceType.None
        ? null
        : TimetableConfiguration(
            id: ScheduleSourceIdentity.create(type, identityValue),
            label: labelFor(type, value),
            type: type,
            value: value,
            includeAll: true,
            exceptions: hidden.map((r) => r['title'] as String).toSet(),
          );
    await database.transaction((tx) async {
      // The marker and migration are committed together, also in background isolates.
      if ((await tx.query('TimetableConfigurationState')).isNotEmpty) return;
      if (primary != null) {
        await tx.insert('TimetableSources', primary.toRow(0));
        for (final title in primary.exceptions) {
          await tx.insert('TimetableModuleSelections', {
            'sourceIdentity': primary.id,
            'title': title,
            'selected': 0,
          });
        }
        await tx.rawUpdate(
          "UPDATE ScheduleEntries SET sourceIdentity=? WHERE sourceIdentity=''",
          [primary.id],
        );
      }
      await tx.insert('TimetableConfigurationState', {'id': 1});
    });
  }

  Future<void> save(List<TimetableConfiguration> sources) async {
    if (sources.map((s) => s.id).toSet().length != sources.length) {
      throw ArgumentError('Duplicate timetable');
    }
    await database.transaction((tx) async {
      final previous = await tx.query('TimetableSources', columns: ['id']);
      final ids = sources.map((s) => s.id).toSet();
      final changedSources =
          previous.length != ids.length ||
          previous.any((row) => !ids.contains(row['id']));
      await tx.delete('TimetableModuleSelections');
      await tx.delete('TimetableSources');
      for (var i = 0; i < sources.length; i++) {
        final source = sources[i];
        await tx.insert('TimetableSources', source.toRow(i));
        for (final title in source.exceptions) {
          await tx.insert('TimetableModuleSelections', {
            'sourceIdentity': source.id,
            'title': title,
            'selected': source.includeAll ? 0 : 1,
          });
        }
      }
      await tx.rawDelete(
        "DELETE FROM ScheduleEntries WHERE sourceIdentity NOT IN (SELECT id FROM TimetableSources)",
      );
      if (changedSources) await tx.delete('ScheduleQueryInformation');
      await tx.rawInsert(
        'INSERT OR IGNORE INTO TimetableConfigurationState(id) VALUES(1)',
      );
      await tx.rawUpdate(
        'UPDATE TimetableConfigurationState SET revision=revision+1 WHERE id=1',
      );
    });
    // Keep onboarding and legacy source-specific preferences coherent.
    await preferences.setScheduleSourceType(
      sources.isEmpty
          ? ScheduleSourceType.None.index
          : sources.first.type.index,
    );
    if (sources.isNotEmpty) {
      final source = sources.first;
      if (source.type == ScheduleSourceType.Rapla)
        await preferences.setRaplaUrl(source.value);
      if (source.type == ScheduleSourceType.Ical ||
          source.type == ScheduleSourceType.Mannheim)
        await preferences.setIcalUrl(source.value);
    }
  }

  Future<Map<String, List<String>>> moduleNames() async {
    final rows = await database.rawQuery(
      'SELECT DISTINCT sourceIdentity, title FROM ScheduleEntries ORDER BY title COLLATE NOCASE',
      [],
    );
    final result = <String, List<String>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row['sourceIdentity'] as String, () => [])
          .add(row['title'] as String);
    }
    return result;
  }

  static String labelFor(ScheduleSourceType type, String value) {
    final uri = Uri.tryParse(value);
    return uri?.queryParameters['file'] ??
        uri?.queryParameters['name'] ??
        (type == ScheduleSourceType.Dualis ? 'Dualis' : uri?.host ?? type.name);
  }
}
