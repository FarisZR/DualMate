import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:dualmate/schedule/reminders/class_reminder_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClassReminderRepository', () {
    test('loads recurring and upcoming one-time rules in one query', () async {
      final database = _RecordingDatabase()
        ..queryResult = [
          {
            'id': 'recurring',
            'scope': 1,
            'canonicalTitle': 'Recht',
            'offsetMinutes': 15,
            'sourceIdentity': 'rapla:a',
            'occurrenceStart': null,
            'occurrenceEnd': null,
          },
          {
            'id': 'one-time',
            'scope': 0,
            'canonicalTitle': 'Mathematik',
            'offsetMinutes': 30,
            'sourceIdentity': 'rapla:a',
            'occurrenceStart': DateTime(2026, 7, 21, 9).millisecondsSinceEpoch,
            'occurrenceEnd': DateTime(2026, 7, 21, 11).millisecondsSinceEpoch,
          },
        ];
      final repository = ClassReminderRepository(database);

      final rules = await repository.loadRelevantRules(
        sourceIdentity: 'rapla:a',
        now: DateTime(2026, 7, 20),
      );

      expect(rules, hasLength(2));
      expect(rules.first.scope, ClassReminderScope.recurring);
      expect(database.queries, hasLength(1));
      expect(database.queries.single.where, contains('sourceIdentity=?'));
      expect(database.queries.single.where, contains('occurrenceStart>?'));
    });

    test(
      'cleanup bulk-deletes past occurrence data and keeps recurring rules',
      () async {
        final database = _RecordingDatabase()..deleteResults.addAll([2, 3]);
        final repository = ClassReminderRepository(database);
        final now = DateTime(2026, 7, 20, 10);

        final result = await repository.deleteExpired(now);

        expect(result.oneTimeRules, 2);
        expect(result.manifestRows, 3);
        expect(database.deletes, hasLength(2));
        expect(database.deletes.first.where, 'scope=? AND occurrenceStart<=?');
        expect(database.deletes.first.whereArgs, [
          0,
          now.millisecondsSinceEpoch,
        ]);
        expect(database.deletes.last.where, 'classStart<=?');
      },
    );

    test('manifest changes are persisted with bulk operations', () async {
      final database = _RecordingDatabase();
      final repository = ClassReminderRepository(database);
      final row = ScheduledClassNotification(
        ruleId: 'rule',
        occurrenceIdentity: 'occurrence',
        sourceIdentity: 'rapla:a',
        notificationId: 42,
        scheduledTime: DateTime(2026, 7, 21, 8, 45),
        classStart: DateTime(2026, 7, 21, 9),
        contentFingerprint: 'fingerprint',
      );

      await repository.applyManifestChanges(
        upserts: [row],
        removedOccurrenceIdentities: ['old-a', 'old-b'],
      );

      expect(database.replaceBatches.single.rows, hasLength(1));
      expect(database.deletes.single.where, contains('IN (?,?)'));
      expect(database.deletes.single.whereArgs, ['old-a', 'old-b']);
    });
  });
}

class _QueryCall {
  final String table;
  final String? where;
  final List<dynamic>? whereArgs;

  _QueryCall(this.table, this.where, this.whereArgs);
}

class _DeleteCall {
  final String table;
  final String? where;
  final List<dynamic>? whereArgs;

  _DeleteCall(this.table, this.where, this.whereArgs);
}

class _ReplaceBatchCall {
  final String table;
  final List<Map<String, dynamic>> rows;

  _ReplaceBatchCall(this.table, this.rows);
}

class _RecordingDatabase extends DatabaseAccess {
  List<Map<String, dynamic>> queryResult = [];
  final List<int> deleteResults = [];
  final List<_QueryCall> queries = [];
  final List<_DeleteCall> deletes = [];
  final List<_ReplaceBatchCall> replaceBatches = [];

  @override
  Future<List<Map<String, dynamic>>> queryRows(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    queries.add(_QueryCall(table, where, whereArgs));
    return queryResult;
  }

  @override
  Future<int> deleteWhere(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    deletes.add(_DeleteCall(table, where, whereArgs));
    return deleteResults.isEmpty ? 0 : deleteResults.removeAt(0);
  }

  @override
  Future<void> insertOrReplaceBatch(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    replaceBatches.add(_ReplaceBatchCall(table, rows));
  }
}
