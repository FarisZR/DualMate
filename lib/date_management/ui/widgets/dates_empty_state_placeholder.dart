import 'package:dualmate/common/ui/colors.dart';
import 'package:flutter/material.dart';

class DatesEmptyStatePlaceholder extends StatelessWidget {
  const DatesEmptyStatePlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomPaint(
            painter: _DatesPlaceholderPainter(
              cardColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              accentColor: colorScheduleEntryClass(context).withValues(alpha: 0.12),
            ),
            child: Container(),
          ),
        );
      },
    );
  }
}

class _DatesPlaceholderPainter extends CustomPainter {
  final Color cardColor;
  final Color accentColor;

  _DatesPlaceholderPainter({
    required this.cardColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cardPaint = Paint()
      ..color = cardColor
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final padding = size.width * 0.08;
    final cardWidth = size.width - (padding * 2);
    final cardHeight = (size.height - padding * 4) / 3;

    for (var i = 0; i < 3; i++) {
      final top = padding + i * (cardHeight + padding);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(padding, top, cardWidth, cardHeight),
        const Radius.circular(12),
      );
      canvas.drawRRect(rect, cardPaint);

      final accentRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          padding + cardWidth * 0.1,
          top + cardHeight * 0.25,
          cardWidth * 0.25,
          cardHeight * 0.35,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(accentRect, accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DatesPlaceholderPainter oldDelegate) {
    return oldDelegate.cardColor != cardColor ||
        oldDelegate.accentColor != accentColor;
  }
}
