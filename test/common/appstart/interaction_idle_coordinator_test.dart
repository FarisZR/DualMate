import 'package:dualmate/common/appstart/interaction_idle_coordinator.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('serializes tasks and waits for interaction leases', (
    tester,
  ) async {
    var frameActive = false;
    final coordinator = InteractionIdleCoordinator(
      isFrameActive: () => frameActive,
    );
    final events = <String>[];

    final first = coordinator.schedule('first', () {
      events.add('first');
    });
    coordinator.schedule('second', () => events.add('second'));

    final lease = coordinator.beginInteraction('drawer');
    await tester.pump();
    expect(events, isEmpty);

    lease.release();
    await _pumpIdleCycle(tester);
    await first.future;
    await _pumpIdleCycle(tester);

    expect(events, ['first', 'second']);
    coordinator.dispose();
  });

  testWidgets('postpones tasks while an injected frame gate is active', (
    tester,
  ) async {
    var frameActive = true;
    final coordinator = InteractionIdleCoordinator(
      isFrameActive: () => frameActive,
    );
    var ran = false;
    final task = coordinator.schedule('animation-gated', () => ran = true);

    await tester.pump();
    expect(ran, isFalse);

    frameActive = false;
    coordinator.notifyFrameStateChanged();
    await _pumpIdleCycle(tester);
    await task.future;
    expect(ran, isTrue);
    coordinator.dispose();
  });

  testWidgets('cancels queued work and releases waiters on disposal', (
    tester,
  ) async {
    final coordinator = InteractionIdleCoordinator(isFrameActive: () => true);
    var ran = false;
    final task = coordinator.schedule('cancelled', () => ran = true);
    final idle = coordinator.waitForIdle();

    task.cancel();
    coordinator.dispose();
    await task.future;
    await idle;

    expect(task.isCancelled, isTrue);
    expect(ran, isFalse);
  });

  testWidgets('deduplicates task ids while a task is queued', (tester) async {
    final coordinator = InteractionIdleCoordinator();
    var calls = 0;
    final first = coordinator.schedule('same', () => calls++);
    final second = coordinator.schedule('same', () => calls++);

    expect(identical(first, second), isTrue);
    await _pumpIdleCycle(tester);
    await first.future;
    expect(calls, 1);
    coordinator.dispose();
  });

  testWidgets('a repeating unrelated animation does not starve idle work', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 100),
    )..repeat();
    final coordinator = InteractionIdleCoordinator();
    var ran = false;

    final task = coordinator.schedule('spinner-safe', () {
      ran = true;
    });
    await _pumpIdleCycle(tester);
    await task.future;

    expect(ran, isTrue);
    controller.dispose();
    coordinator.dispose();
  });

  testWidgets('serial tasks receive an interaction-free frame gap', (
    tester,
  ) async {
    final coordinator = InteractionIdleCoordinator();
    addTearDown(coordinator.dispose);
    final events = <String>[];
    var secondRan = false;

    final first = coordinator.schedule('first', () => events.add('first'));
    final second = coordinator.schedule('second', () {
      secondRan = true;
      events.add('second');
    });

    await _pumpIdleCycle(tester);
    await first.future;
    expect(events, <String>['first']);
    expect(secondRan, isFalse);

    await _pumpIdleCycle(tester);
    await second.future;
    expect(events, <String>['first', 'second']);
  });

  testWidgets('initial quiet period elapses without an interaction lease', (
    tester,
  ) async {
    final coordinator = InteractionIdleCoordinator(
      taskQuietPeriod: const Duration(milliseconds: 180),
    );
    addTearDown(coordinator.dispose);
    var ran = false;
    final task = coordinator.schedule('initial-quiet', () => ran = true);

    await tester.pump(const Duration(milliseconds: 179));
    expect(ran, isFalse);

    await tester.pump(const Duration(milliseconds: 1));
    await _pumpIdleCycle(tester);
    await task.future;
    expect(ran, isTrue);
  });

  testWidgets('background tasks wait for the post-interaction quiet period', (
    tester,
  ) async {
    final coordinator = InteractionIdleCoordinator(
      taskQuietPeriod: const Duration(milliseconds: 180),
    );
    addTearDown(coordinator.dispose);
    var ran = false;
    final task = coordinator.schedule('quiet-task', () => ran = true);
    final lease = coordinator.beginInteraction('drawer');

    lease.release();
    await tester.pump(const Duration(milliseconds: 179));
    expect(ran, isFalse);

    await tester.pump(const Duration(milliseconds: 1));
    await _pumpIdleCycle(tester);
    await task.future;
    expect(ran, isTrue);
  });

  testWidgets('idle waiters do not inherit the background task quiet period', (
    tester,
  ) async {
    final coordinator = InteractionIdleCoordinator(
      taskQuietPeriod: const Duration(milliseconds: 180),
    );
    addTearDown(coordinator.dispose);
    var taskRan = false;
    final task = coordinator.schedule('deferred-task', () => taskRan = true);
    final lease = coordinator.beginInteraction('drawer');
    lease.release();

    final idle = coordinator.waitForIdle();
    await _pumpIdleCycle(tester);
    await idle;

    expect(taskRan, isFalse);

    await tester.pump(const Duration(milliseconds: 180));
    await _pumpIdleCycle(tester);
    await task.future;
    expect(taskRan, isTrue);
  });
}

Future<void> _pumpIdleCycle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}
