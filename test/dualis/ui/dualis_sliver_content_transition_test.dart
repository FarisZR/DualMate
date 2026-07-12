import 'package:dualmate/dualis/ui/widgets/dualis_sliver_content_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('content-key changes restart the fade', (tester) async {
    Widget build(Object contentKey, String label) {
      return MaterialApp(
        home: CustomScrollView(
          slivers: [
            DualisSliverContentTransition(
              showLoading: false,
              contentKey: contentKey,
              loadingBuilder: (_) =>
                  const SliverToBoxAdapter(child: Text('loading')),
              contentBuilder: (_) => SliverToBoxAdapter(child: Text(label)),
            ),
          ],
        ),
      );
    }

    await tester.pumpWidget(build('first', 'first content'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SliverFadeTransition>(find.byType(SliverFadeTransition))
          .opacity
          .value,
      1,
    );

    await tester.pumpWidget(build('second', 'second content'));
    await tester.pump();

    expect(find.text('second content'), findsOneWidget);
    expect(
      tester
          .widget<SliverFadeTransition>(find.byType(SliverFadeTransition))
          .opacity
          .value,
      0,
    );

    await tester.pump(const Duration(milliseconds: 220));
    expect(
      tester
          .widget<SliverFadeTransition>(find.byType(SliverFadeTransition))
          .opacity
          .value,
      1,
    );
  });
}
