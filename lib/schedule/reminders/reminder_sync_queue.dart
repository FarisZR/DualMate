import 'dart:async';

import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';

class ReminderSyncRequest {
  final Schedule schedule;
  final DateTime start;
  final DateTime end;
  final String sourceIdentity;
  final int sourceGeneration;
  final int coalescedRequestCount;
  final DateTime enqueuedAt;

  ReminderSyncRequest({
    required this.schedule,
    required this.start,
    required this.end,
    required this.sourceIdentity,
    required this.sourceGeneration,
    this.coalescedRequestCount = 1,
    DateTime? enqueuedAt,
  }) : enqueuedAt = enqueuedAt ?? DateTime.now();
}

typedef ReminderReconcileCallback =
    Future<void> Function(ReminderSyncRequest request);

class ReminderSyncQueue {
  final ReminderReconcileCallback _reconcile;
  final int Function() _currentGeneration;
  final Future<void> Function(Object error, StackTrace trace)? _onError;
  final List<Object> _pending = [];
  bool _processing = false;
  Completer<void>? _idleCompleter;

  ReminderSyncQueue({
    required ReminderReconcileCallback reconcile,
    required int Function() currentGeneration,
    Future<void> Function(Object error, StackTrace trace)? onError,
  }) : _reconcile = reconcile,
       _currentGeneration = currentGeneration,
       _onError = onError;

  bool get isIdle => !_processing && _pending.isEmpty;

  void enqueue(ReminderSyncRequest request) {
    final mergeIndex = _mergeIndex(request);
    if (mergeIndex >= 0) {
      _pending[mergeIndex] = _merge(
        _pending[mergeIndex] as ReminderSyncRequest,
        request,
      );
    } else {
      _pending.add(request);
    }
    _startProcessing();
  }

  Future<void> runSerialized(Future<void> Function() operation) {
    final completer = Completer<void>();
    _pending.add(_SerializedReminderWork(operation, completer));
    _startProcessing();
    return completer.future;
  }

  void _startProcessing() {
    _idleCompleter ??= Completer<void>();
    if (!_processing) {
      _processing = true;
      unawaited(_process());
    }
  }

  Future<void> drain() async {
    if (isIdle) return;
    await _idleCompleter?.future;
  }

  Future<void> _process() async {
    try {
      while (_pending.isNotEmpty) {
        final work = _pending.removeAt(0);
        if (work is _SerializedReminderWork) {
          try {
            await work.operation();
            work.completer.complete();
          } catch (error, trace) {
            work.completer.completeError(error, trace);
          }
          continue;
        }
        final request = work as ReminderSyncRequest;
        if (request.sourceGeneration != _currentGeneration()) continue;
        try {
          await _reconcile(request);
        } catch (error, trace) {
          try {
            await _onError?.call(error, trace);
          } catch (_) {
            // Reporting must never wedge the serialized work queue.
          }
        }
      }
    } finally {
      _processing = false;
      _idleCompleter?.complete();
      _idleCompleter = null;
    }
  }

  int _mergeIndex(ReminderSyncRequest request) {
    for (var index = _pending.length - 1; index >= 0; index--) {
      final pending = _pending[index];
      if (pending is _SerializedReminderWork) break;
      final pendingRequest = pending as ReminderSyncRequest;
      if (pendingRequest.sourceGeneration == request.sourceGeneration &&
          pendingRequest.sourceIdentity == request.sourceIdentity &&
          _overlaps(pendingRequest, request)) {
        return index;
      }
    }
    return -1;
  }

  bool _overlaps(ReminderSyncRequest a, ReminderSyncRequest b) =>
      !a.end.isBefore(b.start) && !b.end.isBefore(a.start);

  ReminderSyncRequest _merge(ReminderSyncRequest a, ReminderSyncRequest b) {
    final entries = <String, ScheduleEntry>{};
    final overlapStart = a.start.isAfter(b.start) ? a.start : b.start;
    final overlapEnd = a.end.isBefore(b.end) ? a.end : b.end;
    final retainedOlderEntries = a.schedule.entries.where(
      (entry) =>
          !entry.start.isBefore(overlapEnd) || !entry.end.isAfter(overlapStart),
    );
    for (final entry in [...retainedOlderEntries, ...b.schedule.entries]) {
      final key =
          '${entry.start.toUtc().millisecondsSinceEpoch}|${entry.end.toUtc().millisecondsSinceEpoch}|${entry.title}';
      entries[key] = entry;
    }
    return ReminderSyncRequest(
      schedule: Schedule.fromList(entries.values.toList(growable: false)),
      start: a.start.isBefore(b.start) ? a.start : b.start,
      end: a.end.isAfter(b.end) ? a.end : b.end,
      sourceIdentity: a.sourceIdentity,
      sourceGeneration: a.sourceGeneration,
      coalescedRequestCount: a.coalescedRequestCount + b.coalescedRequestCount,
      enqueuedAt: a.enqueuedAt.isBefore(b.enqueuedAt)
          ? a.enqueuedAt
          : b.enqueuedAt,
    );
  }
}

class _SerializedReminderWork {
  final Future<void> Function() operation;
  final Completer<void> completer;

  const _SerializedReminderWork(this.operation, this.completer);
}
