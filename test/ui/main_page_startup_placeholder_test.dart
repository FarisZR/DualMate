import 'package:dualmate/common/i18n/localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:dualmate/ui/main_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestApp() {
    return MaterialApp(
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
      ],
      home: const MainPage(
        initialRoute: 'usefulInformation',
        showAppLaunchDialogs: false,
      ),
    );
  }

  testWidgets('shows a placeholder before the initial section mounts',
      (tester) async {
    await tester.pumpWidget(buildTestApp());

    expect(find.byKey(const ValueKey<String>('main_page_initial_placeholder')),
        findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('mounts the initial section after the startup delay',
      (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey<String>('main_page_initial_placeholder')),
        findsNothing);
    expect(find.byType(ListTile), findsWidgets);
  });
}
