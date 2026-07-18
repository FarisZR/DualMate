import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/schedule/reminders/class_reminder.dart';

class ExpiredReminderDeletionCount {
  final int oneTimeRules;
  final int manifestRows;

  const ExpiredReminderDeletionCount({
    required this.oneTimeRules,
    required this.manifestRows,
  });

  int get total => oneTimeRules + manifestRows;
}

abstract interface class ClassReminderRepositoryApi {
  Future<List<ClassReminderRule>> loadRelevantRules({
    required String sourceIdentity,
    required DateTime now,
  });

  Future<List<ScheduledClassNotification>> loadManifestForWindow({
    required String sourceIdentity,
    required DateTime start,
    required DateTime end,
  });

  Future<void> applyManifestChanges({
    required List<ScheduledClassNotification> upserts,
    required List<String> removedOccurrenceIdentities,
  });

  Future<ExpiredReminderDeletionCount> deleteExpired(DateTime now);

  Future<void> saveRule(ClassReminderRule rule);

  Future<void> deleteRule(String ruleId);
}

class ClassReminderRepository implements ClassReminderRepositoryApi {
  static const rulesTable = 'ClassReminderRules';
  static const manifestTable = 'ScheduledClassNotifications';

  final DatabaseAccess _database;

  ClassReminderRepository(this._database);

  Future<bool> hasAnyRules({String? sourceIdentity}) async {
    final rows = await _database.queryRows(
      rulesTable,
      columns: const ['id'],
      where: sourceIdentity == null ? null : 'sourceIdentity=?',
      whereArgs: sourceIdentity == null ? null : [sourceIdentity],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<ClassReminderRule>> loadRelevantRules({
    required String sourceIdentity,
    required DateTime now,
  }) async {
    final rows = await _database.queryRows(
      rulesTable,
      where: 'sourceIdentity=? AND (scope=? OR occurrenceStart>?)',
      whereArgs: [
        sourceIdentity,
        ClassReminderScope.recurring.index,
        now.millisecondsSinceEpoch,
      ],
    );
    return rows.map(_ruleFromMap).toList(growable: false);
  }

  Future<List<ClassReminderRule>> loadRulesForTitle({
    required String sourceIdentity,
    required String canonicalTitle,
    required DateTime now,
  }) async {
    final rows = await _database.queryRows(
      rulesTable,
      where:
          'sourceIdentity=? AND canonicalTitle=? AND (scope=? OR occurrenceStart>?)',
      whereArgs: [
        sourceIdentity,
        canonicalTitle,
        ClassReminderScope.recurring.index,
        now.millisecondsSinceEpoch,
      ],
    );
    return rows.map(_ruleFromMap).toList(growable: false);
  }

  Future<void> saveRule(ClassReminderRule rule) {
    return _database.insertOrReplace(rulesTable, _ruleToMap(rule)).then((_) {});
  }

  Future<void> deleteRule(String ruleId) async {
    await _database.deleteWhere(rulesTable, where: 'id=?', whereArgs: [ruleId]);
  }

  Future<List<ScheduledClassNotification>> loadManifestForWindow({
    required String sourceIdentity,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _database.queryRows(
      manifestTable,
      where: 'sourceIdentity=? AND classStart>=? AND classStart<?',
      whereArgs: [
        sourceIdentity,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
    );
    return rows.map(_manifestFromMap).toList(growable: false);
  }

  Future<void> applyManifestChanges({
    required List<ScheduledClassNotification> upserts,
    required List<String> removedOccurrenceIdentities,
  }) async {
    if (removedOccurrenceIdentities.isNotEmpty) {
      final placeholders = List.filled(
        removedOccurrenceIdentities.length,
        '?',
      ).join(',');
      await _database.deleteWhere(
        manifestTable,
        where: 'occurrenceIdentity IN ($placeholders)',
        whereArgs: removedOccurrenceIdentities,
      );
    }
    await _database.insertOrReplaceBatch(
      manifestTable,
      upserts.map(_manifestToMap).toList(growable: false),
    );
  }

  Future<ExpiredReminderDeletionCount> deleteExpired(DateTime now) async {
    final cutoff = now.millisecondsSinceEpoch;
    final deletedRules = await _database.deleteWhere(
      rulesTable,
      where: 'scope=? AND occurrenceStart<=?',
      whereArgs: [ClassReminderScope.oneTime.index, cutoff],
    );
    final deletedManifest = await _database.deleteWhere(
      manifestTable,
      where: 'classStart<=?',
      whereArgs: [cutoff],
    );
    return ExpiredReminderDeletionCount(
      oneTimeRules: deletedRules,
      manifestRows: deletedManifest,
    );
  }

  Future<void> clearSource(String sourceIdentity) async {
    await Future.wait([
      _database.deleteWhere(
        rulesTable,
        where: 'sourceIdentity=?',
        whereArgs: [sourceIdentity],
      ),
      _database.deleteWhere(
        manifestTable,
        where: 'sourceIdentity=?',
        whereArgs: [sourceIdentity],
      ),
    ]);
  }

  Future<void> clearAll() async {
    await Future.wait([
      _database.deleteWhere(rulesTable, where: '1=1'),
      _database.deleteWhere(manifestTable, where: '1=1'),
    ]);
  }

  ClassReminderRule _ruleFromMap(Map<String, dynamic> row) {
    return ClassReminderRule(
      id: row['id'] as String,
      scope: ClassReminderScope.values[row['scope'] as int],
      canonicalTitle: row['canonicalTitle'] as String,
      offset: Duration(minutes: row['offsetMinutes'] as int),
      sourceIdentity: row['sourceIdentity'] as String,
      occurrenceStart: _optionalDate(row['occurrenceStart']),
      occurrenceEnd: _optionalDate(row['occurrenceEnd']),
    );
  }

  Map<String, dynamic> _ruleToMap(ClassReminderRule rule) => {
    'id': rule.id,
    'scope': rule.scope.index,
    'canonicalTitle': rule.canonicalTitle,
    'offsetMinutes': rule.offset.inMinutes,
    'sourceIdentity': rule.sourceIdentity,
    'occurrenceStart': rule.occurrenceStart?.millisecondsSinceEpoch,
    'occurrenceEnd': rule.occurrenceEnd?.millisecondsSinceEpoch,
  };

  ScheduledClassNotification _manifestFromMap(Map<String, dynamic> row) {
    return ScheduledClassNotification(
      ruleId: row['ruleId'] as String,
      occurrenceIdentity: row['occurrenceIdentity'] as String,
      sourceIdentity: row['sourceIdentity'] as String,
      notificationId: row['notificationId'] as int,
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(
        row['scheduledTime'] as int,
      ),
      classStart: DateTime.fromMillisecondsSinceEpoch(row['classStart'] as int),
      contentFingerprint: row['contentFingerprint'] as String,
    );
  }

  Map<String, dynamic> _manifestToMap(ScheduledClassNotification row) => {
    'ruleId': row.ruleId,
    'occurrenceIdentity': row.occurrenceIdentity,
    'sourceIdentity': row.sourceIdentity,
    'notificationId': row.notificationId,
    'scheduledTime': row.scheduledTime.millisecondsSinceEpoch,
    'classStart': row.classStart.millisecondsSinceEpoch,
    'contentFingerprint': row.contentFingerprint,
  };

  DateTime? _optionalDate(Object? milliseconds) {
    if (milliseconds is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}
