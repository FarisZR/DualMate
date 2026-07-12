import 'dart:async';

import 'package:dualmate/common/appstart/interaction_idle_coordinator.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/ui/main_page.dart';
import 'package:dualmate/ui/navigation/navigation_entry.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not mount a cold section during drawer close', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final coordinator = InteractionIdleCoordinator();
    final schedule = _FakeEntry('schedule');
    final heavy = _FakeEntry('heavy');

    await tester.pumpWidget(
      _buildApp(
        MainPage(
          initialRoute: 'schedule',
          showAppLaunchDialogs: false,
          entries: [schedule, heavy],
          interactionCoordinator: coordinator,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pump();
    expect(schedule.buildCount, 1);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('drawer_item_heavy')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(heavy.buildCount, 0);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    await tester.pump();
    expect(heavy.buildCount, 1);

    coordinator.dispose();
  });

  testWidgets('opening the drawer does not prepare every cold section', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final coordinator = InteractionIdleCoordinator();
    final schedule = _FakeEntry('schedule');
    final heavy = _FakeEntry('heavy');

    await tester.pumpWidget(
      _buildApp(
        MainPage(
          initialRoute: 'schedule',
          showAppLaunchDialogs: false,
          entries: [schedule, heavy],
          interactionCoordinator: coordinator,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(heavy.preparationStarted, isFalse);
    expect(heavy.buildCount, 0);
    coordinator.dispose();
  });

  testWidgets('cold navigation does not wait for preparation to finish', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final coordinator = InteractionIdleCoordinator();
    final preparationGate = Completer<void>();
    final schedule = _FakeEntry('schedule');
    final heavy = _FakeEntry('heavy', preparationGate: preparationGate);

    await tester.pumpWidget(
      _buildApp(
        MainPage(
          initialRoute: 'schedule',
          showAppLaunchDialogs: false,
          entries: [schedule, heavy],
          interactionCoordinator: coordinator,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pump();
    expect(schedule.buildCount, 1);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('drawer_item_heavy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    for (var index = 0; index < 5; index++) {
      await tester.pump();
    }
    await coordinator.waitForIdle();
    await tester.pump();

    expect(heavy.preparationStarted, isTrue);
    expect(heavy.preparationCompleted, isFalse);
    expect(heavy.buildCount, 1);
    expect(
      find.byKey(const ValueKey<String>('main_section_heavy')),
      findsOneWidget,
    );

    preparationGate.complete();
    await tester.pump();
    coordinator.dispose();
  });

  testWidgets('scroll interaction lease is released after scrolling', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final coordinator = InteractionIdleCoordinator();
    final schedule = _FakeEntry('schedule', scrollable: true);

    await tester.pumpWidget(
      _buildApp(
        MainPage(
          initialRoute: 'schedule',
          showAppLaunchDialogs: false,
          entries: [schedule],
          interactionCoordinator: coordinator,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pump();

    await tester.drag(
      find.byKey(const ValueKey<String>('scrollable_schedule')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(coordinator.hasActiveInteraction, isFalse);
    coordinator.dispose();
  });
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _buildApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: const [
      LocalizationDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      DefaultCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('de')],
    home: home,
  );
}

class _FakeEntry extends NavigationEntry<_FakeViewModel> {
  _FakeEntry(this._route, {this.preparationGate, this.scrollable = false});

  final String _route;
  final Completer<void>? preparationGate;
  final bool scrollable;
  int buildCount = 0;
  bool preparationStarted = false;
  bool preparationCompleted = false;

  @override
  String get route => _route;

  @override
  String title(BuildContext context) => _route;

  @override
  Widget icon(BuildContext context) => const Icon(Icons.circle);

  @override
  _FakeViewModel initViewModel() => _FakeViewModel();

  @override
  Future<void> prepareSection() async {
    preparationStarted = true;
    final gate = preparationGate;
    if (gate != null) {
      await gate.future;
    }
    preparationCompleted = true;
  }

  @override
  Widget build(BuildContext context) {
    buildCount++;
    if (scrollable) {
      return ListView.builder(
        key: ValueKey<String>('scrollable_$_route'),
        itemCount: 40,
        itemBuilder: (_, index) =>
            SizedBox(height: 48, child: Text('$_route-$index')),
      );
    }
    return Text(_route);
  }
}

class _FakeViewModel extends BaseViewModel {}
