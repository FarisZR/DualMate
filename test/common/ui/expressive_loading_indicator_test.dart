import 'package:dualmate/common/ui/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('morphs while loading and stops for reduced motion', (
    tester,
  ) async {
    Future<void> show({required bool reducedMotion}) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: const Center(child: ExpressiveLoadingIndicator()),
        ),
      ),
    );
    ShapeDecoration shape() =>
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(ExpressiveLoadingIndicator),
                        matching: find.byType(DecoratedBox),
                      )
                      .last,
                )
                .decoration
            as ShapeDecoration;

    await show(reducedMotion: false);
    final initial = shape();
    await tester.pump(const Duration(milliseconds: 325));
    expect(shape(), isNot(initial));
    expect(shape().shape, isNot(initial.shape));
    // Exercise the entire sequence, including the wrap back to its first shape.
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 325));
      expect(tester.takeException(), isNull);
    }
    await show(reducedMotion: true);
    await tester.pumpAndSettle();
    final still = shape();
    await tester.pump(const Duration(seconds: 1));
    expect(shape(), still);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await show(reducedMotion: false);
    await tester.pump(const Duration(milliseconds: 325));
    expect(shape().shape, isNot(still.shape));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
