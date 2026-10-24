import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/dualis/model/credentials.dart';
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
  for (final empty in [false, true]) {
    testWidgets('Dualis can configure the primary timetable (empty: $empty)', (
      tester,
    ) async {
      final model = _Model(empty: empty);
      await _open(tester, model);
      if (empty) {
        await tester.tap(find.text('Add timetable'));
      } else {
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit timetable'));
      }
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<ScheduleSourceType>),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dualis'), findsWidgets);
      await tester.tap(find.text('Dualis').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'My class');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'student',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Ok'));
      await tester.pumpAndSettle();
      expect(model.configured?.type, ScheduleSourceType.Dualis);
      expect(model.configured?.value, 'student');
      expect(model.configured?.includeAll, isTrue);
      expect(model.credentials?.username, 'student');
      expect(model.credentials?.password, 'secret');
      if (!empty) expect(model.replacingId, 'rapla:b4');
      model.dispose();
    });
  }

  testWidgets('an additional timetable cannot create another Dualis account', (
    tester,
  ) async {
    final model = _Model();
    await _open(tester, model);
    await tester.scrollUntilVisible(
      find.text('Add timetable'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add timetable'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ScheduleSourceType>));
    await tester.pumpAndSettle();
    expect(find.text('Dualis'), findsNothing);
    model.dispose();
  });

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
          expect(
            find.byKey(const ValueKey('timetable_save_changes')),
            findsOneWidget,
          );
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
  final bool empty;
  TimetableConfiguration? configured;
  Credentials? credentials;
  String? replacingId;
  _Model({this.empty = false})
    : super(
        repository: _Repository(),
        sourceProvider: _Sources(),
        scheduleProvider: _Provider(),
        entryRepository: _Entries(),
      );
  @override
  Future<void> put(
    TimetableConfiguration source, {
    String? replacingId,
    Credentials? dualisCredentials,
  }) async {
    configured = source;
    credentials = dualisCredentials;
    this.replacingId = replacingId;
  }

  @override
  Future<void> load() async {
    sources = empty
        ? []
        : [
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

Future<void> _open(WidgetTester tester, _Model model) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [LocalizationDelegate()],
      home: TimetableCustomizationPage(viewModel: model),
    ),
  );
  await tester.pumpAndSettle();
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
