import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/ui/schedule_navigation_entry.dart';
import 'package:dualmate/schedule/ui/schedule_page.dart';
import 'package:dualmate/ui/main_page.dart';
import 'package:dualmate/ui/navigation/router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';

void main() {
  setUp(() {
    KiwiContainer().clear();
    KiwiContainer().registerInstance<ScheduleProvider>(_FakeScheduleProvider());
    KiwiContainer().registerInstance<ScheduleSourceProvider>(
      _FakeScheduleSourceProvider(),
    );
  });

  tearDown(() {
    KiwiContainer().clear();
    SchedulePage.resetSharedState();
  });

  Widget buildTestApp() {
    return MaterialApp(
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
      ],
      home: const MainPage(
        initialRoute: 'schedule',
        showAppLaunchDialogs: false,
      ),
    );
  }

  testWidgets('shows a placeholder before the initial section mounts',
      (tester) async {
    await tester.pumpWidget(buildTestApp());

    expect(find.byKey(const ValueKey<String>('main_page_initial_placeholder')),
        findsOneWidget);
  });

  testWidgets('mounts the initial section after the startup delay',
      (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey<String>('main_page_initial_placeholder')),
        findsNothing);

    // Tear down the mounted section so its deferred timers are cancelled
    // before the binding checks for pending timers. The schedule view model is
    // owned by the long-lived navigation entry (provided via a `.value`
    // provider that does not auto-dispose), so it must be disposed by hand.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    SchedulePage.resetSharedState();
    navigationEntries
        .whereType<ScheduleNavigationEntry>()
        .first
        .viewModel()
        .dispose();
    await tester.pump();
  });
}

class _FakeScheduleProvider implements ScheduleProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  @override
  bool didSetupCorrectly() => false;

  @override
  Future<bool> setupScheduleSource() async => false;

  @override
  void addDidChangeScheduleSourceCallback(OnDidChangeScheduleSource callback) {}

  @override
  void removeDidChangeScheduleSourceCallback(
    OnDidChangeScheduleSource callback,
  ) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleSourceProvider call: $invocation',
    );
  }
}
