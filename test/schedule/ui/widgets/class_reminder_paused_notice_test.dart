import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/ui/widgets/class_reminder_paused_notice.dart';
import 'package:dualmate/ui/banner_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the schedule banner design with concise German copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          LocalizationDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('de')],
        home: Scaffold(
          body: ClassReminderPausedNotice(onFixPermissions: () {}),
        ),
      ),
    );

    expect(find.byType(BannerWidget), findsOneWidget);
    expect(find.text('Klassenerinnerungen pausiert'), findsOneWidget);
    expect(
      find.text(
        'Aktiviere Benachrichtigungen und genaue Alarme, damit sie wieder funktionieren.',
      ),
      findsOneWidget,
    );
    expect(find.text('BERECHTIGUNGEN PRÜFEN'), findsOneWidget);

    final title = tester.widget<Text>(
      find.text('Klassenerinnerungen pausiert'),
    );
    expect(title.style?.fontWeight, FontWeight.w600);
  });
}
