import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_entry_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const longTitle =
      'Intercultural Communication Group 2 with long additional details';

  testWidgets('compact cards use readable text and tighter padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildEntryHost(
        width: 62,
        height: 120,
        title: longTitle,
      ),
    );

    final textWidget = tester.widget<Text>(find.text(longTitle));
    expect(textWidget.overflow, TextOverflow.clip);
    expect(textWidget.maxLines ?? 0, greaterThanOrEqualTo(6));
    expect((textWidget.style?.fontSize ?? 0), greaterThanOrEqualTo(13.5));

    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byType(InkWell),
        matching: find.byType(Padding),
      ),
    );
    final insets = padding.padding as EdgeInsets;
    expect(insets.left, 1.0);
    expect(insets.top, 1.0);
  });

  testWidgets('wider cards keep standard overflow strategy', (tester) async {
    await tester.pumpWidget(
      _buildEntryHost(
        width: 140,
        height: 160,
        title: longTitle,
      ),
    );

    final textWidget = tester.widget<Text>(find.text(longTitle));
    expect(textWidget.overflow, TextOverflow.ellipsis);
    expect(textWidget.maxLines, greaterThan(3));
    expect((textWidget.style?.fontSize ?? 0), greaterThanOrEqualTo(14.0));
  });
}

Widget _buildEntryHost({
  required double width,
  required double height,
  required String title,
}) {
  final entry = ScheduleEntry(
    start: DateTime(2026, 2, 10, 9),
    end: DateTime(2026, 2, 10, 10),
    title: title,
    details: 'Details',
    professor: 'Professor',
    room: 'R1',
    type: ScheduleEntryType.Class,
  );

  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: ScheduleEntryWidget(
            scheduleEntry: entry,
            onScheduleEntryTap: (_) {},
          ),
        ),
      ),
    ),
  );
}
