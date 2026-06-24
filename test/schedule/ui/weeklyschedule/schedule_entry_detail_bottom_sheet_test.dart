import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/schedule_entry_detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders as a draggable scrollable sheet', (tester) async {
    await tester.pumpWidget(_buildApp(entry: _entry(details: 'Short details')));
    await _showSheet(tester);
    await tester.pumpAndSettle();

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long details do not cause a layout overflow', (tester) async {
    final longDetails = List<String>.filled(
      60,
      'A very long details line.',
    ).join(' ');
    await tester.pumpWidget(_buildApp(entry: _entry(details: longDetails)));
    await _showSheet(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('A very long details line'), findsOneWidget);
  });

  testWidgets('sheet is expandable: dragging up grows it past its initial size', (
    tester,
  ) async {
    // Short content so an upward gesture expands the sheet rather than
    // scrolling within it.
    await tester.pumpWidget(_buildApp(entry: _entry(details: 'Short details')));
    await _showSheet(tester);
    await tester.pumpAndSettle();

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    // The sheet is configured to expand well beyond its starting size.
    expect(sheet.expand, isFalse);
    expect(sheet.maxChildSize, greaterThan(sheet.initialChildSize));
    expect(sheet.minChildSize, lessThan(sheet.initialChildSize));

    final initial = _currentSheetSize(tester);
    expect(initial, closeTo(sheet.initialChildSize, 0.02));

    // Fling the sheet upwards to expand it. Upward gestures never dismiss.
    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
      1500,
    );
    await tester.pumpAndSettle();

    // The sheet must still be present (not dismissed) and have grown.
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(_currentSheetSize(tester), greaterThan(initial));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows all core fields for a short entry', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        entry: _entry(title: 'Math', details: 'Bring laptop'),
      ),
    );
    await _showSheet(tester);
    await tester.pumpAndSettle();

    expect(find.text('Math'), findsOneWidget);
    expect(find.text('Prof Test'), findsOneWidget);
    expect(find.text('Bring laptop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

double _currentSheetSize(WidgetTester tester) {
  // Measure the visible sheet body (the scroll view fills the current sheet
  // extent), relative to the full screen height.
  final bodyHeight = tester.getSize(find.byType(SingleChildScrollView)).height;
  final parentHeight = tester.getSize(find.byType(Scaffold)).height;
  return bodyHeight / parentHeight;
}

Future<void> _showSheet(WidgetTester tester) async {
  await tester.tap(find.text('show'));
}

ScheduleEntry _entry({String title = 'Title', String details = ''}) {
  return ScheduleEntry(
    start: DateTime(2026, 6, 24, 8, 0),
    end: DateTime(2026, 6, 24, 9, 30),
    title: title,
    details: details,
    professor: 'Prof Test',
    room: 'Room A',
    type: ScheduleEntryType.Class,
  );
}

Widget _buildApp({required ScheduleEntry entry}) {
  return MaterialApp(
    localizationsDelegates: const [
      LocalizationDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('de')],
    home: Scaffold(
      body: SafeArea(
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    ScheduleEntryDetailBottomSheet(scheduleEntry: entry),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(12.0),
                  ),
                ),
              ),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    ),
  );
}
