import 'package:dualmate/common/ui/colors.dart';
import 'package:flutter/material.dart';

class ScheduleEmptyStatePlaceholder extends StatelessWidget {
  final int columns;
  final int rows;

  const ScheduleEmptyStatePlaceholder({
    Key? key,
    this.columns = 5,
    this.rows = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border.all(
              color: colorScheduleGridGridLines(context),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _SchedulePlaceholderGridPainter(
                    columns: columns,
                    rows: rows,
                    gridColor: colorScheduleGridGridLines(context),
                    accentColor:
                        colorScheduleEntryClass(context).withOpacity(0.12),
                  ),
                  child: Container(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SchedulePlaceholderGridPainter extends CustomPainter {
  final int columns;
  final int rows;
  final Color gridColor;
  final Color accentColor;

  _SchedulePlaceholderGridPainter({
    required this.columns,
    required this.rows,
    required this.gridColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final columnWidth = size.width / columns;
    final rowHeight = size.height / rows;

    for (var i = 1; i < columns; i++) {
      final x = columnWidth * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (var i = 1; i < rows; i++) {
      final y = rowHeight * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final placeholderBlocks = [
      Rect.fromLTWH(columnWidth * 0.2, rowHeight * 1.2, columnWidth * 0.6,
          rowHeight * 0.8),
      Rect.fromLTWH(columnWidth * 1.3, rowHeight * 3.1, columnWidth * 0.5,
          rowHeight * 1.1),
      Rect.fromLTWH(columnWidth * 2.1, rowHeight * 5.4, columnWidth * 0.7,
          rowHeight * 0.9),
      Rect.fromLTWH(columnWidth * 3.2, rowHeight * 2.2, columnWidth * 0.6,
          rowHeight * 1.3),
    ];

    for (final block in placeholderBlocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(block, const Radius.circular(6)),
        accentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SchedulePlaceholderGridPainter oldDelegate) {
    return oldDelegate.columns != columns ||
        oldDelegate.rows != rows ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.accentColor != accentColor;
  }
}
