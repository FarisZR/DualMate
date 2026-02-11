import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ScheduleGrid extends CustomPaint {
  final double fromHour;
  final double toHour;
  final double timeLabelsWidth;
  final double dateLabelsHeight;
  final int columns;
  final Color gridLinesColor;

  ScheduleGrid(this.fromHour, this.toHour, this.timeLabelsWidth,
      this.dateLabelsHeight, this.columns, this.gridLinesColor)
      : super(
            painter: ScheduleGridCustomPaint(
          fromHour,
          toHour,
          timeLabelsWidth,
          dateLabelsHeight,
          columns,
          gridLinesColor,
        ));
}

class ScheduleGridCustomPaint extends CustomPainter {
  final double fromHour;
  final double toHour;
  final double timeLabelsWidth;
  final double dateLabelsHeight;
  final int columns;
  final Color gridLineColor;

  ScheduleGridCustomPaint(
    this.fromHour,
    this.toHour,
    this.timeLabelsWidth,
    this.dateLabelsHeight,
    this.columns,
    this.gridLineColor,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final secondaryPaint = Paint()
      ..color = gridLineColor
      ..strokeWidth = 1;

    drawHorizontalLines(size, canvas, secondaryPaint);
    drawVerticalLines(size, canvas, secondaryPaint);
  }

  void drawHorizontalLines(Size size, Canvas canvas, Paint secondaryPaint) {
    final visibleHours = toHour - fromHour;
    if (visibleHours <= 0) return;

    final visibleHeight = size.height - dateLabelsHeight;
    final firstHourMarker = fromHour.ceil();
    final lastHourMarker = toHour.floor();

    for (var marker = firstHourMarker; marker <= lastHourMarker; marker++) {
      final normalized = (marker - fromHour) / visibleHours;
      final y = (visibleHeight * normalized) + dateLabelsHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), secondaryPaint);
    }
  }

  void drawVerticalLines(Size size, Canvas canvas, Paint secondaryPaint) {
    for (var i = 0; i < columns; i++) {
      var x = ((size.width - timeLabelsWidth) / columns) * i + timeLabelsWidth;

      canvas.drawLine(Offset(x, 0), Offset(x, size.height), secondaryPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is! ScheduleGridCustomPaint) return true;
    return fromHour != oldDelegate.fromHour ||
        toHour != oldDelegate.toHour ||
        timeLabelsWidth != oldDelegate.timeLabelsWidth ||
        dateLabelsHeight != oldDelegate.dateLabelsHeight ||
        columns != oldDelegate.columns ||
        gridLineColor != oldDelegate.gridLineColor;
  }
}
