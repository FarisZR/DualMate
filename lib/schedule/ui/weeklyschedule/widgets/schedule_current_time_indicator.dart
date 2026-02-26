import 'package:flutter/material.dart';

class ScheduleCurrentTimeIndicator extends StatelessWidget {
  static const Key lineKey = ValueKey('schedule-current-time-line');
  static const Key markerKey = ValueKey('schedule-current-time-marker');

  final int dayIndex;
  final int columns;
  final double yOffset;
  final Color color;
  final double strokeWidth;
  final double markerDiameter;

  const ScheduleCurrentTimeIndicator({
    super.key,
    required this.dayIndex,
    required this.columns,
    required this.yOffset,
    required this.color,
    this.strokeWidth = 2,
    this.markerDiameter = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (columns <= 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final columnWidth = constraints.maxWidth / columns;
          final top = yOffset - (strokeWidth / 2);
          final markerTop = yOffset - (markerDiameter / 2);
          final left = dayIndex * columnWidth;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              Positioned(
                left: left,
                top: top,
                width: columnWidth,
                height: strokeWidth,
                child: DecoratedBox(
                  key: lineKey,
                  decoration: BoxDecoration(color: color),
                ),
              ),
              Positioned(
                left: left,
                top: markerTop,
                width: markerDiameter,
                height: markerDiameter,
                child: DecoratedBox(
                  key: markerKey,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
