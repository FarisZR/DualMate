import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ScheduleGrid extends StatelessWidget {
  final double fromHour;
  final double toHour;
  final double timeLabelsWidth;
  final double dateLabelsHeight;
  final int columns;
  final Color gridLinesColor;

  const ScheduleGrid(
    this.fromHour,
    this.toHour,
    this.timeLabelsWidth,
    this.dateLabelsHeight,
    this.columns,
    this.gridLinesColor, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(
          key: const ValueKey<String>('schedule-grid-static-columns'),
          child: CustomPaint(
            painter: ScheduleGridVerticalLinesPainter(
              timeLabelsWidth,
              columns,
              gridLinesColor,
            ),
          ),
        ),
        RepaintBoundary(
          key: const ValueKey<String>('schedule-grid-hour-lines'),
          child: CustomPaint(
            painter: ScheduleGridHorizontalLinesPainter(
              fromHour,
              toHour,
              dateLabelsHeight,
              gridLinesColor,
            ),
          ),
        ),
      ],
    );
  }
}

class ScheduleGridVerticalLinesPainter extends CustomPainter {
  final double timeLabelsWidth;
  final int columns;
  final Color gridLineColor;

  ScheduleGridVerticalLinesPainter(
    this.timeLabelsWidth,
    this.columns,
    this.gridLineColor,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridLineColor
      ..strokeWidth = 1;
    for (var i = 0; i < columns; i++) {
      final x =
          ((size.width - timeLabelsWidth) / columns) * i + timeLabelsWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScheduleGridVerticalLinesPainter oldDelegate) {
    return timeLabelsWidth != oldDelegate.timeLabelsWidth ||
        columns != oldDelegate.columns ||
        gridLineColor != oldDelegate.gridLineColor;
  }
}

class ScheduleGridHorizontalLinesPainter extends CustomPainter {
  final double fromHour;
  final double toHour;
  final double dateLabelsHeight;
  final Color gridLineColor;

  ScheduleGridHorizontalLinesPainter(
    this.fromHour,
    this.toHour,
    this.dateLabelsHeight,
    this.gridLineColor,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridLineColor
      ..strokeWidth = 1;
    final visibleHours = toHour - fromHour;
    if (visibleHours <= 0) return;

    final visibleHeight = size.height - dateLabelsHeight;
    final firstHourMarker = fromHour.ceil();
    final lastHourMarker = toHour.floor();
    for (var marker = firstHourMarker; marker <= lastHourMarker; marker++) {
      final normalized = (marker - fromHour) / visibleHours;
      final y = (visibleHeight * normalized) + dateLabelsHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScheduleGridHorizontalLinesPainter oldDelegate) {
    return fromHour != oldDelegate.fromHour ||
        toHour != oldDelegate.toHour ||
        dateLabelsHeight != oldDelegate.dateLabelsHeight ||
        gridLineColor != oldDelegate.gridLineColor;
  }
}
