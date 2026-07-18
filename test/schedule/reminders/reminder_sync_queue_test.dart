import 'dart:async';

import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/reminders/reminder_sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'enqueue returns immediately while slow reconciliation continues',
    () async {
      final blocker = Completer<void>();
      final queue = ReminderSyncQueue(
        reconcile: (_) => blocker.future,
        currentGeneration: () => 1,
      );

      queue.enqueue(_request(DateTime(2026, 7, 20), DateTime(2026, 7, 27)));

      expect(queue.isIdle, isFalse);
      blocker.complete();
      await queue.drain();
      expect(queue.isIdle, isTrue);
    },
  );

  test(
    'overlapping queued windows are coalesced and processed serially',
    () async {
      final firstBlocker = Completer<void>();
      final requests = <ReminderSyncRequest>[];
      var active = 0;
      var maxActive = 0;
      final queue = ReminderSyncQueue(
        currentGeneration: () => 1,
        reconcile: (request) async {
          active++;
          maxActive = active > maxActive ? active : maxActive;
          requests.add(request);
          if (requests.length == 1) await firstBlocker.future;
          active--;
        },
      );

      queue.enqueue(_request(DateTime(2026, 7, 20), DateTime(2026, 7, 27)));
      await Future<void>.delayed(Duration.zero);
      queue.enqueue(_request(DateTime(2026, 7, 24), DateTime(2026, 7, 31)));
      queue.enqueue(_request(DateTime(2026, 7, 27), DateTime(2026, 8, 3)));
      firstBlocker.complete();
      await queue.drain();

      expect(maxActive, 1);
      expect(requests, hasLength(2));
      expect(requests.last.start, DateTime(2026, 7, 24));
      expect(requests.last.end, DateTime(2026, 8, 3));
      expect(requests.last.coalescedRequestCount, 2);
    },
  );

  test('stale source-generation work is discarded', () async {
    var generation = 2;
    var calls = 0;
    final queue = ReminderSyncQueue(
      currentGeneration: () => generation,
      reconcile: (_) async => calls++,
    );

    queue.enqueue(
      _request(DateTime(2026, 7, 20), DateTime(2026, 7, 27), generation: 1),
    );
    await queue.drain();

    expect(calls, 0);
  });

  test('newer overlapping snapshots replace stale entries', () async {
    final firstBlocker = Completer<void>();
    final requests = <ReminderSyncRequest>[];
    final queue = ReminderSyncQueue(
      currentGeneration: () => 1,
      reconcile: (request) async {
        requests.add(request);
        if (requests.length == 1) await firstBlocker.future;
      },
    );
    final firstStart = DateTime(2026, 7, 20);
    queue.enqueue(_request(firstStart, DateTime(2026, 7, 21)));
    await Future<void>.delayed(Duration.zero);
    queue.enqueue(_request(DateTime(2026, 7, 22), DateTime(2026, 7, 29)));
    queue.enqueue(
      ReminderSyncRequest(
        schedule: Schedule.fromList(const []),
        start: DateTime(2026, 7, 22),
        end: DateTime(2026, 7, 29),
        sourceIdentity: 'rapla:a',
        sourceGeneration: 1,
      ),
    );
    firstBlocker.complete();
    await queue.drain();

    expect(requests.last.schedule.entries, isEmpty);
  });

  test('an error reporter failure cannot wedge the queue', () async {
    final queue = ReminderSyncQueue(
      currentGeneration: () => 1,
      reconcile: (_) => Future<void>.error(StateError('reconcile')),
      onError: (_, _) => Future<void>.error(StateError('report')),
    );

    queue.enqueue(_request(DateTime(2026, 7, 20), DateTime(2026, 7, 27)));
    await queue.drain();

    expect(queue.isIdle, isTrue);
  });

  test(
    'serialized work waits for active reconciliation and blocks newer work',
    () async {
      final reconcileBlocker = Completer<void>();
      final cleanupBlocker = Completer<void>();
      final events = <String>[];
      var reconcileCount = 0;
      final queue = ReminderSyncQueue(
        currentGeneration: () => 1,
        reconcile: (_) async {
          reconcileCount++;
          events.add('reconcile-$reconcileCount-start');
          if (reconcileCount == 1) await reconcileBlocker.future;
          events.add('reconcile-$reconcileCount-end');
        },
      );

      queue.enqueue(_request(DateTime(2026, 7, 20), DateTime(2026, 7, 21)));
      await Future<void>.delayed(Duration.zero);
      final cleanup = queue.runSerialized(() async {
        events.add('cleanup-start');
        await cleanupBlocker.future;
        events.add('cleanup-end');
      });
      queue.enqueue(_request(DateTime(2026, 7, 20), DateTime(2026, 7, 21)));

      expect(events, ['reconcile-1-start']);
      reconcileBlocker.complete();
      await Future<void>.delayed(Duration.zero);
      expect(events, ['reconcile-1-start', 'reconcile-1-end', 'cleanup-start']);

      cleanupBlocker.complete();
      await cleanup;
      await queue.drain();
      expect(events, [
        'reconcile-1-start',
        'reconcile-1-end',
        'cleanup-start',
        'cleanup-end',
        'reconcile-2-start',
        'reconcile-2-end',
      ]);
    },
  );
}

ReminderSyncRequest _request(
  DateTime start,
  DateTime end, {
  int generation = 1,
}) => ReminderSyncRequest(
  schedule: Schedule.fromList([
    ScheduleEntry(
      start: start.add(const Duration(hours: 9)),
      end: start.add(const Duration(hours: 11)),
      title: 'Recht',
      details: '',
      professor: '',
      room: '',
      type: ScheduleEntryType.Class,
    ),
  ]),
  start: start,
  end: end,
  sourceIdentity: 'rapla:a',
  sourceGeneration: generation,
);
