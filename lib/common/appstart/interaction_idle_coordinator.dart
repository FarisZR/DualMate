import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

typedef IdleTaskAction = FutureOr<void> Function();

/// Coordinates work that is safe to run only when the user and the frame
/// scheduler are idle.
///
/// Interaction ids are counted rather than represented by one boolean. This
/// lets overlapping pointer, scroll, route, and animation signals release
/// independently without allowing an old signal to make the app look idle.
class InteractionIdleCoordinator {
  InteractionIdleCoordinator({
    bool Function()? isFrameActive,
    Duration taskQuietPeriod = Duration.zero,
  }) : _isFrameActive = isFrameActive ?? _neverFrameBlocked,
       _taskQuietPeriod = taskQuietPeriod,
       _taskQuietElapsed = taskQuietPeriod == Duration.zero;

  static final InteractionIdleCoordinator instance = InteractionIdleCoordinator(
    taskQuietPeriod: const Duration(milliseconds: 180),
  );

  final bool Function() _isFrameActive;
  final Duration _taskQuietPeriod;
  final Map<String, int> _activeInteractions = <String, int>{};
  final List<_QueuedIdleTask> _queue = <_QueuedIdleTask>[];
  final Map<String, _QueuedIdleTask> _tasksById = <String, _QueuedIdleTask>{};
  final List<Completer<void>> _idleWaiters = <Completer<void>>[];

  bool _pumpScheduled = false;
  bool _frameWaitScheduled = false;
  bool _idleFrameScheduled = false;
  bool _idleFrameObserved = false;
  bool _taskRunning = false;
  bool _disposed = false;
  bool _taskQuietElapsed;
  Timer? _taskQuietTimer;

  bool get isDisposed => _disposed;

  bool get hasActiveInteraction => _activeInteractions.isNotEmpty;

  bool get isIdle => !hasActiveInteraction && !_isFrameActive();

  static bool _neverFrameBlocked() => false;

  /// Starts an interaction and returns a lease that can be released exactly
  /// once by its owner.
  InteractionLease beginInteraction(String interactionId) {
    if (_disposed) {
      return InteractionLease._(() {});
    }

    _activeInteractions.update(
      interactionId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    _taskQuietTimer?.cancel();
    _taskQuietTimer = null;
    if (_taskQuietPeriod > Duration.zero) {
      _taskQuietElapsed = false;
    }
    _idleFrameObserved = false;
    _wake();
    return InteractionLease._(() => endInteraction(interactionId));
  }

  void endInteraction(String interactionId) {
    if (_disposed) return;

    final count = _activeInteractions[interactionId];
    if (count == null) return;
    if (count <= 1) {
      _activeInteractions.remove(interactionId);
    } else {
      _activeInteractions[interactionId] = count - 1;
    }
    if (!hasActiveInteraction) {
      _taskQuietTimer?.cancel();
      if (_taskQuietPeriod == Duration.zero) {
        _taskQuietElapsed = true;
      } else {
        _taskQuietElapsed = false;
        _taskQuietTimer = Timer(_taskQuietPeriod, () {
          _taskQuietTimer = null;
          _taskQuietElapsed = true;
          _wake();
        });
      }
    }
    _idleFrameObserved = false;
    _wake();
  }

  /// Schedules one task. Tasks are FIFO and strictly serialized, so section
  /// preparation cannot fan out several cache/database reads at once.
  ///
  /// A task remains queued while an interaction or frame animation is active.
  /// [delay] preserves existing startup timing without making that timing the
  /// only signal used to decide whether work is safe to run.
  InteractionIdleTask schedule(
    String taskId,
    IdleTaskAction action, {
    Duration delay = Duration.zero,
  }) {
    final existing = _tasksById[taskId];
    if (existing != null) return existing.handle;

    final task = _QueuedIdleTask(
      coordinator: this,
      id: taskId,
      action: action,
      ready: delay == Duration.zero,
    );
    _tasksById[taskId] = task;
    _queue.add(task);
    _idleFrameObserved = false;
    _ensureInitialQuietPeriodTimer();

    if (delay > Duration.zero) {
      task.timer = Timer(delay, () {
        if (task.cancelled || _disposed) return;
        task.ready = true;
        _wake();
      });
    }

    _wake();
    return task.handle;
  }

  Future<void> waitForIdle() {
    if (_disposed || (isIdle && _idleFrameObserved)) {
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _idleWaiters.add(completer);
    _wake();
    return completer.future;
  }

  /// Wakes the coordinator after an externally observed frame-state change.
  /// This is useful for scroll/animation adapters and deterministic tests.
  void notifyFrameStateChanged() => _wake();

  void _wake() {
    if (_disposed || _pumpScheduled) return;
    _pumpScheduled = true;
    scheduleMicrotask(() {
      _pumpScheduled = false;
      _pump();
    });
  }

  void _pump() {
    if (_disposed) return;

    if (hasActiveInteraction) {
      _idleFrameObserved = false;
      return;
    }

    if (_isFrameActive()) {
      _idleFrameObserved = false;
      _waitForNextFrameIfNeeded();
      return;
    }

    if (!_idleFrameObserved) {
      if (_idleWaiters.isEmpty && _hasReadyTask && !_taskQuietPeriodElapsed) {
        return;
      }
      _waitForInteractionFreeFrame();
      return;
    }

    _completeIdleWaiters();
    if (_taskRunning) return;

    _QueuedIdleTask? nextTask;
    for (final task in _queue) {
      if (!task.cancelled && task.ready) {
        nextTask = task;
        break;
      }
    }
    if (nextTask == null) return;
    if (!_taskQuietPeriodElapsed) {
      return;
    }

    _queue.remove(nextTask);
    _taskRunning = true;
    nextTask.started = true;
    unawaited(_runTask(nextTask));
  }

  Future<void> _runTask(_QueuedIdleTask task) async {
    try {
      if (!task.cancelled && !_disposed) {
        await task.action();
      }
      task.complete();
    } catch (error, trace) {
      task.completeError(error, trace);
    } finally {
      if (identical(_tasksById[task.id], task)) {
        _tasksById.remove(task.id);
      }
      _taskRunning = false;
      _idleFrameObserved = false;
      _pump();
    }
  }

  void _waitForNextFrameIfNeeded() {
    if (_frameWaitScheduled) return;
    _frameWaitScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameWaitScheduled = false;
      _wake();
    });
  }

  void _waitForInteractionFreeFrame() {
    if (_idleFrameScheduled) return;
    _idleFrameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _idleFrameScheduled = false;
      if (_disposed) return;
      if (hasActiveInteraction || _isFrameActive()) {
        _idleFrameObserved = false;
      } else {
        _idleFrameObserved = true;
      }
      _wake();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  bool get _hasReadyTask => _queue.any((task) => !task.cancelled && task.ready);

  void _ensureInitialQuietPeriodTimer() {
    if (_taskQuietPeriod == Duration.zero ||
        _taskQuietElapsed ||
        hasActiveInteraction ||
        _taskQuietTimer != null) {
      return;
    }
    _taskQuietTimer = Timer(_taskQuietPeriod, () {
      if (_disposed) return;
      _taskQuietTimer = null;
      _taskQuietElapsed = true;
      _wake();
    });
  }

  bool get _taskQuietPeriodElapsed => _taskQuietElapsed;

  void _completeIdleWaiters() {
    if (!isIdle || !_idleFrameObserved) return;
    final waiters = List<Completer<void>>.from(_idleWaiters);
    _idleWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  void _cancel(_QueuedIdleTask task) {
    if (task.cancelled) return;
    task.cancelled = true;
    task.timer?.cancel();
    _queue.remove(task);
    _tasksById.remove(task.id);
    if (!task.started) task.complete();
    _wake();
  }

  /// Stops queued work owned by this coordinator. A task already running is
  /// allowed to finish because Dart futures cannot be force-cancelled safely.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _taskQuietTimer?.cancel();
    _taskQuietTimer = null;
    for (final task in List<_QueuedIdleTask>.from(_queue)) {
      task.cancelled = true;
      task.timer?.cancel();
      task.complete();
    }
    _queue.clear();
    _tasksById.clear();
    for (final waiter in _idleWaiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _idleWaiters.clear();
  }
}

/// Bridges root route transitions into the shared idle coordinator.
class InteractionAwareNavigatorObserver extends NavigatorObserver {
  InteractionAwareNavigatorObserver(this.coordinator);

  final InteractionIdleCoordinator coordinator;
  final Map<Route<dynamic>, InteractionLease> _routeLeases =
      <Route<dynamic>, InteractionLease>{};
  final Map<Route<dynamic>, AnimationStatusListener> _routeListeners =
      <Route<dynamic>, AnimationStatusListener>{};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackRoute(route, 'push', AnimationStatus.completed);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _trackRoute(route, 'pop', AnimationStatus.dismissed);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) _releaseRoute(oldRoute);
    if (newRoute != null) {
      _trackRoute(newRoute, 'replace', AnimationStatus.completed);
    }
  }

  void _trackRoute(
    Route<dynamic> route,
    String phase,
    AnimationStatus settledStatus,
  ) {
    _releaseRoute(route);
    final lease = coordinator.beginInteraction(
      'route.${phase}.${identityHashCode(route)}',
    );
    _routeLeases[route] = lease;
    final animation = route is ModalRoute<dynamic> ? route.animation : null;
    if (animation == null || animation.status == settledStatus) {
      scheduleMicrotask(() => _releaseRoute(route));
      return;
    }

    void onStatusChanged(AnimationStatus status) {
      if (status != settledStatus) return;
      _releaseRoute(route);
    }

    _routeListeners[route] = onStatusChanged;
    animation.addStatusListener(onStatusChanged);
  }

  void _releaseRoute(Route<dynamic> route) {
    final listener = _routeListeners.remove(route);
    final animation = route is ModalRoute<dynamic> ? route.animation : null;
    if (listener != null && animation != null) {
      animation.removeStatusListener(listener);
    }
    _routeLeases.remove(route)?.release();
  }

  void dispose() {
    for (final route in List<Route<dynamic>>.from(_routeLeases.keys)) {
      _releaseRoute(route);
    }
    _routeListeners.clear();
  }
}

class InteractionLease {
  InteractionLease._(this._release);

  final void Function() _release;
  bool _released = false;

  bool get isReleased => _released;

  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}

class InteractionIdleTask {
  InteractionIdleTask._(this._queued);

  final _QueuedIdleTask _queued;

  Future<void> get future => _queued.completer.future;
  bool get isCancelled => _queued.cancelled;
  bool get isStarted => _queued.started;

  void cancel() => _queued.coordinator._cancel(_queued);
}

class _QueuedIdleTask {
  _QueuedIdleTask({
    required this.coordinator,
    required this.id,
    required this.action,
    required this.ready,
  }) {
    handle = InteractionIdleTask._(this);
  }

  final InteractionIdleCoordinator coordinator;
  final String id;
  final IdleTaskAction action;
  final Completer<void> completer = Completer<void>();
  late final InteractionIdleTask handle;
  Timer? timer;
  bool ready;
  bool started = false;
  bool cancelled = false;

  void complete() {
    if (!completer.isCompleted) completer.complete();
  }

  void completeError(Object error, StackTrace trace) {
    if (!completer.isCompleted) completer.completeError(error, trace);
  }
}
