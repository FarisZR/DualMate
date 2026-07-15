import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses subdued divider colors throughout light and dark themes', (
    tester,
  ) async {
    final light = ColorPalettes.buildTheme(AppTheme.Light);
    final dark = ColorPalettes.buildTheme(AppTheme.Dark);

    expect(light.dividerColor, const Color(0xFFD8D8D8));
    expect(light.dividerTheme.color, const Color(0xFFD8D8D8));
    expect(dark.dividerColor, const Color(0xFF3A3A3A));
    expect(dark.dividerTheme.color, const Color(0xFF3A3A3A));

    late BorderSide resolvedBorder;
    await tester.pumpWidget(
      MaterialApp(
        theme: dark,
        home: Builder(
          builder: (context) {
            resolvedBorder = Divider.createBorderSide(context);
            return const Scaffold(body: Divider());
          },
        ),
      ),
    );

    expect(resolvedBorder.color, const Color(0xFF3A3A3A));
  });
}
