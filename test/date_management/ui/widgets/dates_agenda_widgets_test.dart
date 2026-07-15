import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:dualmate/date_management/ui/widgets/dates_agenda_layout.dart';
import 'package:dualmate/date_management/ui/widgets/dates_agenda_row.dart';
import 'package:dualmate/date_management/ui/widgets/dates_render_data.dart';
import 'package:dualmate/date_management/ui/widgets/important_event_section_heading.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test(
    'resolves compact wide and scaled layout once from list constraints',
    () {
      final compact = DatesAgendaLayoutSpec.resolve(
        availableWidth: 320,
        textScaler: TextScaler.noScaling,
      );
      final wide = DatesAgendaLayoutSpec.resolve(
        availableWidth: 1200,
        textScaler: TextScaler.noScaling,
      );
      final scaled = DatesAgendaLayoutSpec.resolve(
        availableWidth: 360,
        textScaler: const TextScaler.linear(2),
      );
      final scaled150 = DatesAgendaLayoutSpec.resolve(
        availableWidth: 360,
        textScaler: const TextScaler.linear(1.5),
      );

      expect(compact.listHorizontalInset, 16);
      expect(compact.listVerticalPadding, 8);
      expect(compact.contentWidth, 288);
      expect(compact.railWidth, 64);
      expect(compact.gap, 12);
      expect(compact.showCategoryIcon, isFalse);
      expect(wide.listHorizontalInset, 180);
      expect(wide.contentWidth, 840);
      expect(wide.railWidth, 72);
      expect(wide.gap, 16);
      expect(wide.showCategoryIcon, isTrue);
      expect(scaled.railWidth, greaterThan(64));
      expect(scaled150.railWidth, inExclusiveRange(64, scaled.railWidth));
    },
  );

  testWidgets(
    'renders a non-interactive filled agenda row with one semantics node',
    (tester) async {
      final row = _eventRow();
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        _app(
          ImportantEventAgendaRow(
            key: const Key('agenda_row'),
            data: row,
            layoutSpec: DatesAgendaLayoutSpec.resolve(
              availableWidth: 360,
              textScaler: TextScaler.noScaling,
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(IntrinsicHeight), findsNothing);
      expect(find.byType(IntrinsicWidth), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byKey(const Key('dates_agenda_category_icon')), findsNothing);
      expect(
        tester.getSemantics(find.byKey(const Key('agenda_row'))),
        matchesSemantics(label: row.event.semanticsLabel),
      );
      semantics.dispose();
    },
  );

  testWidgets('shows the category icon only when the event surface fits it', (
    tester,
  ) async {
    final row = _eventRow();
    await tester.pumpWidget(
      _app(
        ImportantEventAgendaRow(
          data: row,
          layoutSpec: DatesAgendaLayoutSpec.resolve(
            availableWidth: 600,
            textScaler: TextScaler.noScaling,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('dates_agenda_category_icon')), findsOneWidget);
  });

  testWidgets('supports 320 logical pixels and 200 percent text scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final row = _eventRow(
      title: 'A deliberately long examination title that wraps safely',
      professor: 'Prof. Ada Lovelace and Prof. Grace Hopper',
    );

    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ImportantEventAgendaRow(
            data: row,
            layoutSpec: DatesAgendaLayoutSpec.resolve(
              availableWidth: 320,
              textScaler: const TextScaler.linear(2),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(row.event.event.title), findsOneWidget);
  });

  testWidgets('marks exam-week headings as level-two semantic headers', (
    tester,
  ) async {
    final heading = _examWeekHeading();
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _app(
        ImportantEventSectionHeading(
          key: const Key('agenda_heading'),
          data: heading,
          layoutSpec: DatesAgendaLayoutSpec.resolve(
            availableWidth: 600,
            textScaler: TextScaler.noScaling,
          ),
          isFirst: true,
        ),
      ),
    );

    expect(find.byType(Card), findsNothing);
    expect(
      tester.getSemantics(find.byKey(const Key('agenda_heading'))),
      matchesSemantics(label: heading.semanticsLabel, isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('uses approved dark exam surface tokens', (tester) async {
    final row = _eventRow();
    await tester.pumpWidget(
      _app(
        ImportantEventAgendaRow(
          data: row,
          layoutSpec: DatesAgendaLayoutSpec.resolve(
            availableWidth: 600,
            textScaler: TextScaler.noScaling,
          ),
        ),
        theme: AppTheme.Dark,
      ),
    );

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.color, const Color(0xFF3A1B1D));
    expect(card.elevation, 0);
    expect(card.margin, EdgeInsets.zero);
    expect(card.clipBehavior, Clip.none);
  });
}

ImportantEventAgendaRowRenderData _eventRow({
  String title = 'Algorithms exam',
  String professor = 'Prof. Ada Lovelace',
}) {
  final event = ImportantEvent(
    title: title,
    start: DateTime(2026, 7, 7, 8),
    end: DateTime(2026, 7, 7, 10),
    professor: professor,
    type: ScheduleEntryType.Exam,
  );
  final renderData = DatesRenderData.prepare(
    sections: [
      ImportantEventSection(
        kind: ImportantEventSectionKind.standalone,
        header: null,
        events: [event],
      ),
    ],
    entries: const [],
    locale: 'en',
    now: DateTime(2026, 1, 1),
  );
  return renderData.raplaItems.single.row!;
}

ImportantEventSectionHeadingRenderData _examWeekHeading() {
  final header = ImportantEvent(
    title: 'Klausurwoche',
    start: DateTime(2026, 7, 27),
    end: DateTime(2026, 7, 31),
    type: ScheduleEntryType.SpecialEvent,
  );
  final renderData = DatesRenderData.prepare(
    sections: [
      ImportantEventSection(
        kind: ImportantEventSectionKind.examWeek,
        header: header,
        events: const [],
      ),
    ],
    entries: const [],
    locale: 'en',
    now: DateTime(2026, 1, 1),
  );
  return renderData.raplaItems.single.heading!;
}

Widget _app(Widget child, {AppTheme theme = AppTheme.Light}) {
  return MaterialApp(
    theme: ColorPalettes.buildTheme(theme),
    localizationsDelegates: const [
      LocalizationDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('de')],
    home: Scaffold(body: child),
  );
}
