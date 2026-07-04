import 'package:dualmate/common/util/platform_util.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone portrait display applies portrait-only orientations', (
    tester,
  ) async {
    _setDisplay(tester, physicalSize: const Size(1080, 2400), dpr: 3);
    final calls = <List<DeviceOrientation>>[];
    final lock = _buildLock(tester, calls);
    addTearDown(() => _resetDisplay(tester, lock));

    await lock.attach();

    expect(calls, [
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    ]);
  });

  testWidgets('phone landscape display is still forced to portrait', (
    tester,
  ) async {
    _setDisplay(tester, physicalSize: const Size(2400, 1080), dpr: 3);
    final calls = <List<DeviceOrientation>>[];
    final lock = _buildLock(tester, calls);
    addTearDown(() => _resetDisplay(tester, lock));

    await lock.attach();

    expect(calls, [
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    ]);
  });

  testWidgets(
    'tablet landscape display leaves system orientation unrestricted',
    (tester) async {
      _setDisplay(tester, physicalSize: const Size(2560, 1600), dpr: 2);
      final calls = <List<DeviceOrientation>>[];
      final lock = _buildLock(tester, calls);
      addTearDown(() => _resetDisplay(tester, lock));

      await lock.attach();

      expect(calls, [<DeviceOrientation>[]]);
    },
  );

  testWidgets(
    'display metric changes re-evaluate without restricting large screens',
    (tester) async {
      _setDisplay(tester, physicalSize: const Size(1080, 2400), dpr: 3);
      final calls = <List<DeviceOrientation>>[];
      final lock = _buildLock(tester, calls);
      addTearDown(() => _resetDisplay(tester, lock));

      await lock.attach();
      expect(calls.last, [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      calls.clear();
      _setDisplay(tester, physicalSize: const Size(2560, 1600), dpr: 2);
      await tester.pump();

      expect(calls, [<DeviceOrientation>[]]);

      calls.clear();
      _setDisplay(tester, physicalSize: const Size(2800, 1800), dpr: 2);
      await tester.pump();

      expect(calls, isEmpty);
    },
  );
}

AdaptiveOrientationLock _buildLock(
  WidgetTester tester,
  List<List<DeviceOrientation>> calls,
) {
  return AdaptiveOrientationLock(
    viewProvider: () => tester.view,
    setPreferredOrientations: (orientations) async {
      calls.add(List<DeviceOrientation>.of(orientations));
    },
  );
}

void _setDisplay(
  WidgetTester tester, {
  required Size physicalSize,
  required double dpr,
}) {
  tester.view.display.devicePixelRatio = dpr;
  tester.view.display.size = physicalSize;
}

void _resetDisplay(WidgetTester tester, AdaptiveOrientationLock lock) {
  lock.detach();
  tester.view.display.reset();
}
