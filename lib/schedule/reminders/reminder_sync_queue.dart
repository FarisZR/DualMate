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
  final List<ReminderSyncRequest> _pending = [];
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
    final mergeIndex = _pending.indexWhere(
      (pending) =>
          pending.sourceGeneration == request.sourceGeneration &&
          pending.sourceIdentity == request.sourceIdentity &&
          _overlaps(pending, request),
    );
    if (mergeIndex >= 0) {
      _pending[mergeIndex] = _merge(_pending[mergeIndex], request);
    } else {
      _pending.add(request);
    }
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
    while (_pending.isNotEmpty) {
      final request = _pending.removeAt(0);
      if (request.sourceGeneration != _currentGeneration()) continue;
      try {
        await _reconcile(request);
      } catch (error, trace) {
        await _onError?.call(error, trace);
      }
    }
    _processing = false;
    _idleCompleter?.complete();
    _idleCompleter = null;
  }

  bool _overlaps(ReminderSyncRequest a, ReminderSyncRequest b) =>
      !a.end.isBefore(b.start) && !b.end.isBefore(a.start);

  ReminderSyncRequest _merge(ReminderSyncRequest a, ReminderSyncRequest b) {
    final entries = <String, ScheduleEntry>{};
    for (final entry in [...a.schedule.entries, ...b.schedule.entries]) {
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
