import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/schedule_entry_detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _haptics = const [];

void main() {
  setUp(() {
    _haptics = <String>[];
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) {
          if (call.method == 'HapticFeedback.vibrate' &&
              call.arguments is String) {
            _haptics.add(call.arguments as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

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

  testWidgets('starts at the medium size and is configured to expand', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(entry: _entry(details: 'Short details')));
    await _showSheet(tester);
    await tester.pumpAndSettle();

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(sheet.expand, isFalse);
    // Built-in linear snap is intentionally disabled; snapping is driven
    // manually with a snappy Material 3 decelerate curve (see implementation).
    expect(sheet.snap, isFalse);
    expect(sheet.maxChildSize, greaterThan(sheet.initialChildSize));
    expect(sheet.minChildSize, lessThan(sheet.initialChildSize));
    expect(_currentSheetSize(tester), closeTo(sheet.initialChildSize, 0.02));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'partial upward drag snaps to the large size with a selection haptic',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(entry: _entry(details: 'Short details')),
      );
      await _showSheet(tester);
      await tester.pumpAndSettle();

      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );

      // Drag up past the snap midpoint (but not all the way to max) so the
      // manual snap engages toward the large size.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();

      expect(_currentSheetSize(tester), closeTo(sheet.maxChildSize, 0.03));
      expect(_haptics, contains('HapticFeedbackType.selectionClick'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manually dragging the sheet fully expanded fires a haptic without snap',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(entry: _entry(details: 'Short details')),
      );
      await _showSheet(tester);
      await tester.pumpAndSettle();

      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );

      // Drag the sheet all the way to the top (clamps at max) so it reaches the
      // expanded state by hand — no release-snap is needed.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();

      expect(_currentSheetSize(tester), closeTo(sheet.maxChildSize, 0.03));
      // A selection haptic must fire when the sheet arrives at expanded, even
      // though the user (not the snap) drove it there.
      expect(_haptics, contains('HapticFeedbackType.selectionClick'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('partial downward drag from expanded snaps back to medium', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(entry: _entry(details: 'Short details')));
    await _showSheet(tester);
    await tester.pumpAndSettle();

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );

    // Expand first.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(_currentSheetSize(tester), closeTo(sheet.maxChildSize, 0.03));

    // Drag back down past the midpoint, then release.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 220));
    await tester.pumpAndSettle();

    expect(_currentSheetSize(tester), closeTo(sheet.initialChildSize, 0.03));
    // Arriving back at the standard state also fires a haptic.
    expect(_haptics, contains('HapticFeedbackType.selectionClick'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'snapping recovers after a snap is interrupted by a drag',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(entry: _entry(details: 'Short details')),
      );
      await _showSheet(tester);
      await tester.pumpAndSettle();

      final scrollable = find.byType(SingleChildScrollView);
      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );

      // 1. Start a snap toward expanded, then interrupt it mid-flight.
      await tester.drag(scrollable, const Offset(0, -220));
      await tester.pump(const Duration(milliseconds: 50)); // snap mid-flight
      await tester.drag(scrollable, const Offset(0, 60)); // interrupts the snap
      await tester.pumpAndSettle();

      // 2. Re-establish a known expanded state with a direct (non-snap) drag.
      await tester.drag(scrollable, const Offset(0, -400)); // clamps at max
      await tester.pump();

      // 3. Slowly drag down to an intermediate size and release with almost no
      //    velocity. A recovered snap settles at the standard size; a guard
      //    stuck true (interrupted animateTo never completing) leaves it
      //    mid-screen.
      await tester.timedDrag(
        scrollable,
        const Offset(0, 210),
        const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();

      expect(_currentSheetSize(tester), closeTo(sheet.initialChildSize, 0.06));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dragging the sheet far down dismisses it', (tester) async {
    await tester.pumpWidget(_buildApp(entry: _entry(details: 'Short details')));
    await _showSheet(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleEntryDetailBottomSheet), findsOneWidget);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 600));
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleEntryDetailBottomSheet), findsNothing);
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
