import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/schedule/ui/customization/timetable_module_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AppTheme.Light, AppTheme.Dark]) {
    testWidgets('entire module row toggles with accessible state in $theme', (
      tester,
    ) async {
      bool? changed;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: ColorPalettes.buildTheme(theme),
          home: Scaffold(
            body: TimetableModuleTile(
              title: 'Software Engineering',
              selected: true,
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(TimetableModuleTile)),
        matchesSemantics(
          label: 'Software Engineering',
          isEnabled: true,
          hasEnabledState: true,
          hasCheckedState: true,
          isChecked: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await tester.tap(find.text('Software Engineering'));
      expect(changed, isFalse);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
