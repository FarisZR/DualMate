import 'dart:math' as math;

import 'package:flutter/widgets.dart';

@immutable
class DatesAgendaLayoutSpec {
  static const double maxContentWidth = 840;

  final double listHorizontalInset;
  final double listVerticalPadding;
  final double contentWidth;
  final double railWidth;
  final double gap;
  final bool showCategoryIcon;

  const DatesAgendaLayoutSpec({
    required this.listHorizontalInset,
    required this.listVerticalPadding,
    required this.contentWidth,
    required this.railWidth,
    required this.gap,
    required this.showCategoryIcon,
  });

  factory DatesAgendaLayoutSpec.resolve({
    required double availableWidth,
    required TextScaler textScaler,
  }) {
    final isWide = availableWidth >= 600;
    final baseHorizontalInset = isWide ? 24.0 : 16.0;
    final horizontalInset = isWide
        ? math.max(baseHorizontalInset, (availableWidth - maxContentWidth) / 2)
        : baseHorizontalInset;
    final contentWidth = math.max(
      0,
      math.min(maxContentWidth, availableWidth - (horizontalInset * 2)),
    );
    final scaleAdjustment = ((textScaler.scale(1) - 1).clamp(0.0, 1.0) * 16)
        .toDouble();
    final railWidth = (isWide ? 72.0 : 64.0) + scaleAdjustment;
    final gap = isWide ? 16.0 : 12.0;
    final eventSurfaceWidth = contentWidth - railWidth - gap;

    return DatesAgendaLayoutSpec(
      listHorizontalInset: horizontalInset,
      listVerticalPadding: isWide ? 12 : 8,
      contentWidth: contentWidth.toDouble(),
      railWidth: railWidth,
      gap: gap,
      showCategoryIcon: eventSurfaceWidth >= 260,
    );
  }
}
