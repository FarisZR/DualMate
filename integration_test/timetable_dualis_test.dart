import 'package:dualmate/common/appstart/performance_fixture_mode.dart';
import 'package:dualmate/common/appstart/service_injector.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/dualis/model/credentials.dart';
import 'package:dualmate/dualis/service/fake_account_dualis_scraper_decorator.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/timetable_repository.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:dualmate/schedule/ui/customization/timetable_customization_page.dart';
import 'package:dualmate/schedule/ui/customization/timetable_customization_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiwi/kiwi.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'replace primary with Dualis, save, reload and query a cold source',
    (tester) async {
      if (!isPerformanceFixtureMode) {
        throw StateError('Use the separate PERF_TEST_OFFLINE_FIXTURES app.');
      }
      binding.testTextInput.register();
      addTearDown(binding.testTextInput.unregister);
      injectServices(false);
      final c = KiwiContainer();
      final repository = c.resolve<TimetableRepository>();
      final sources = c.resolve<ScheduleSourceProvider>();
      final preferences = c.resolve<PreferencesProvider>();
      await preferences.storeDualisCredentials(Credentials('', ''));
      await repository.save([
        TimetableConfiguration(
          id: 'rapla:b4',
          label: 'My class',
          type: ScheduleSourceType.Rapla,
          value: 'https://rapla.example/rapla?key=b4',
          includeAll: true,
        ),
        TimetableConfiguration(
          id: 'ical:b6',
          label: 'B6',
          type: ScheduleSourceType.Ical,
          value: 'https://example.com/b6.ics',
          exceptions: {'Formal Languages'},
        ),
      ]);
      final model = TimetableCustomizationViewModel(
        repository: repository,
        sourceProvider: sources,
        scheduleProvider: c.resolve<ScheduleProvider>(),
        entryRepository: c.resolve<ScheduleEntryRepository>(),
      );
      addTearDown(model.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: ColorPalettes.buildTheme(AppTheme.Light),
          localizationsDelegates: const [
            LocalizationDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => TimetableCustomizationPage(viewModel: model),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit timetable'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<ScheduleSourceType>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dualis').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        FakeAccountDualisScraperDecorator.demoUsername,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        FakeAccountDualisScraperDecorator.demoPassword,
      );
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('timetable-tablet-dualis-source');
      await tester.tap(find.widgetWithText(FilledButton, 'Ok'));
      await tester.pumpAndSettle();
      // Secure storage and the active source change only on the page's Save.
      expect((await preferences.loadDualisCredentials()).username, isEmpty);
      expect((await repository.load()).first.type, ScheduleSourceType.Rapla);
      expect(model.sources.first.type, ScheduleSourceType.Dualis);
      expect(model.modules.containsKey(model.sources.first.id), isTrue);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('timetable-tablet-dualis');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      final saved = await repository.load();
      expect(saved.first.type, ScheduleSourceType.Dualis);
      expect(saved.first.includeAll, isTrue);
      expect(saved.last.exceptions, {'Formal Languages'});
      expect(
        (await preferences.loadDualisCredentials()).username,
        FakeAccountDualisScraperDecorator.demoUsername,
      );
      final cold = await sources.createSource(saved.first);
      expect(cold.canQuery(), isTrue);
      expect(sources.currentScheduleSource.canQuery(), isTrue);
      final now = DateTime.now();
      final result = await cold.querySchedule(
        now,
        now.add(const Duration(days: 7)),
      );
      // The public review account has a valid login and an empty timetable.
      expect(result.errors, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
