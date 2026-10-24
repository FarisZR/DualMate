import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/timetable_repository.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:dualmate/schedule/ui/customization/timetable_customization_page.dart';
import 'package:dualmate/schedule/ui/customization/timetable_customization_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AppTheme.Light, AppTheme.Dark]) {
    for (final language in ['en', 'de']) {
      for (final width in [320.0, 393.0, 800.0]) {
        testWidgets('customization fits $width / $language / $theme', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, width == 800 ? 1280 : 852);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final model = _Model();
          await tester.pumpWidget(
            MaterialApp(
              theme: ColorPalettes.buildTheme(theme),
              locale: Locale(language),
              localizationsDelegates: const [
                LocalizationDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('de')],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 1.8 : 1),
                ),
                child: child!,
              ),
              home: TimetableCustomizationPage(viewModel: model),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('rapla:b4/Software Engineering')),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(
            find.byKey(const ValueKey('rapla:b4/Software Engineering')),
          );
          expect(model.sources.first.includes('Software Engineering'), isFalse);
          expect(model.sources.last.includes('Software Engineering'), isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          model.dispose();
        });
      }
    }
  }
}

class _Model extends TimetableCustomizationViewModel {
  _Model()
    : super(
        repository: _Repository(),
        sourceProvider: _Sources(),
        scheduleProvider: _Provider(),
        entryRepository: _Entries(),
      );
  @override
  Future<void> load() async {
    sources = [
      TimetableConfiguration(
        id: 'rapla:b4',
        label: 'TINF25B4',
        type: ScheduleSourceType.Rapla,
        value: 'https://example.com',
        includeAll: true,
      ),
      TimetableConfiguration(
        id: 'ical:b6',
        label: 'TINF25B6',
        type: ScheduleSourceType.Ical,
        value: 'https://example.com/b6.ics',
        exceptions: {'Software Engineering'},
      ),
    ];
    modules = {
      for (final source in sources)
        source.id: [
          'Software Engineering',
          'Datenbanksysteme und betriebliche Informationssysteme',
        ],
    };
    loading = false;
    notifyListeners();
  }
}

class _Repository implements TimetableRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sources implements ScheduleSourceProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Provider implements ScheduleProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Entries implements ScheduleEntryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
