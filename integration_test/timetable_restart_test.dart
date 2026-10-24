import 'package:dualmate/common/appstart/performance_fixture_mode.dart';
import 'package:dualmate/common/appstart/service_injector.dart';
import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/timetable_repository.dart';
import 'package:dualmate/schedule/ui/customization/timetable_customization_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiwi/kiwi.dart';

/// Run in a new process after timetable_customization_test.dart. Deliberately
/// neither seeds data nor starts the loopback calendar server from that test.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('saved mixed timetable survives a process restart offline', (
    tester,
  ) async {
    if (!isPerformanceFixtureMode)
      throw StateError('Use the isolated fixture app.');
    injectServices(false);
    final c = KiwiContainer();
    await c.resolve<ScheduleSourceProvider>().setupScheduleSource();
    final saved = await c.resolve<TimetableRepository>().load();
    expect(saved.map((s) => s.label), ['B4', 'B6']);
    expect(saved.first.includes('Mathematics'), isFalse);
    expect(saved.first.includes('Software Engineering'), isTrue);
    expect(saved.last.includes('Formal Languages'), isTrue);
    expect(saved.last.includes('Mathematics'), isFalse);
    final now = DateTime.now();
    final visible = await c.resolve<ScheduleProvider>().getCachedSchedule(
      now.subtract(const Duration(days: 1)),
      now.add(const Duration(days: 7)),
    );
    expect(visible.entries.map((e) => e.title).toSet(), {
      'Software Engineering',
      'Database Systems',
      'Formal Languages',
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ColorPalettes.buildTheme(AppTheme.Light),
        locale: const Locale('en'),
        localizationsDelegates: const [
          LocalizationDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('de')],
        home: const TimetableCustomizationPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('B4'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
