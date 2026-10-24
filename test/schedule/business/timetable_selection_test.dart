import 'dart:async';

import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/combined_schedule_source.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancelling a combined refresh cancels every source', () async {
    final first = _WaitingSource();
    final second = _WaitingSource();
    final token = CancellationToken();
    final pending = CombinedScheduleSource({'b4': first, 'b6': second})
        .querySchedule(DateTime(2026), DateTime(2027), token);
    final expectation = expectLater(
      pending,
      throwsA(isA<OperationCancelledException>()),
    );
    token.cancel();
    await expectation;
    expect(first.cancelled, isTrue);
    expect(second.cancelled, isTrue);
  });
  test('primary defaults include future modules; additions opt in', () {
    final primary = configuration('b4', includeAll: true, exceptions: {'Math'});
    final additional = configuration('b6', exceptions: {'Math'});
    expect(primary.includes('Math'), isFalse);
    expect(primary.includes('New module'), isTrue);
    expect(additional.includes('Math'), isTrue);
    expect(additional.includes('New module'), isFalse);
    expect(primary.withModule('Math', true).includes('Math'), isTrue);
    expect(primary.includes('Math'), isFalse);
  });

  test('identical lessons retain independent source identity', () async {
    final combined = CombinedScheduleSource({'b4': _Source(), 'b6': _Source()});
    final result = await combined.querySchedule(DateTime(2026), DateTime(2027));
    expect(result.schedule.entries.map((e) => e.sourceIdentity), ['b4', 'b6']);
    expect(
      result.schedule.entries[0].equalsWithIdIgnored(
        result.schedule.entries[1],
      ),
      isFalse,
    );
    expect(
      result.schedule.entries[0].copyWith(title: 'Changed').sourceIdentity,
      'b4',
    );
  });

  test(
    'duplicate events are collapsed inside each source while URLs survive',
    () async {
      final combined = CombinedScheduleSource({
        'b4': _Source(duplicate: true),
        'b6': _Source(duplicate: true),
      });
      final result = await combined.querySchedule(
        DateTime(2026),
        DateTime(2027),
      );
      expect(result.schedule.entries, hasLength(2));
      expect(result.schedule.entries.map((e) => e.sourceIdentity), [
        'b4',
        'b6',
      ]);
      expect(result.schedule.urls, [
        'https://example.com/calendar',
        'https://example.com/calendar',
      ]);
    },
  );

  test(
    'one failed source cannot overwrite the combined offline cache',
    () async {
      final combined = CombinedScheduleSource({
        'b4': _Source(),
        'b6': _Source(fail: true),
      });
      await expectLater(
        combined.querySchedule(DateTime(2026), DateTime(2027)),
        throwsA(isA<ScheduleQueryFailedException>()),
      );
    },
  );
}

class _WaitingSource implements ScheduleSource {
  bool cancelled = false;
  @override
  bool canQuery() => true;
  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? token,
  ]) {
    final result = Completer<ScheduleQueryResult>();
    token!.setCancellationCallback(() {
      cancelled = true;
      result.completeError(OperationCancelledException());
    });
    return result.future;
  }
}

TimetableConfiguration configuration(
  String id, {
  bool includeAll = false,
  Set<String> exceptions = const {},
}) => TimetableConfiguration(
  id: id,
  label: id,
  type: ScheduleSourceType.Ical,
  value: 'https://example.com/$id.ics',
  includeAll: includeAll,
  exceptions: exceptions,
);

class _Source implements ScheduleSource {
  final bool fail;
  final bool duplicate;
  _Source({this.fail = false, this.duplicate = false});
  @override
  bool canQuery() => true;
  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? token,
  ]) async {
    if (fail) throw ScheduleQueryFailedException('offline');
    final schedule = Schedule()
      ..addEntry(
        ScheduleEntry(
          start: from,
          end: from.add(const Duration(hours: 1)),
          title: 'Math',
          details: '',
          professor: '',
          room: '',
          type: ScheduleEntryType.Class,
        ),
      );
    if (duplicate) schedule.addEntry(schedule.entries.first);
    schedule.urls.add('https://example.com/calendar');
    return ScheduleQueryResult(schedule, []);
  }
}
