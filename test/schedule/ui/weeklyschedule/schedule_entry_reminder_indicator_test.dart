import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_entry_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows filled bell only for an active reminder', (tester) async {
    await tester.pumpWidget(_app(active: true));
    expect(find.byIcon(Icons.notifications), findsOneWidget);

    await tester.pumpWidget(_app(active: false));
    expect(find.byIcon(Icons.notifications), findsNothing);
  });

  testWidgets('shows muted bell when reminder is paused', (tester) async {
    await tester.pumpWidget(_app(active: true, paused: true));
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
  });
}

Widget _app({required bool active, bool paused = false}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 100,
      height: 60,
      child: ScheduleEntryWidget(
        scheduleEntry: ScheduleEntry(
          start: DateTime(2026, 7, 20, 9),
          end: DateTime(2026, 7, 20, 11),
          title: 'Recht',
          details: '',
          professor: '',
          room: '',
          type: ScheduleEntryType.Class,
        ),
        onScheduleEntryTap: (_) {},
        reminderActive: active,
        reminderPaused: paused,
      ),
    ),
  ),
);
