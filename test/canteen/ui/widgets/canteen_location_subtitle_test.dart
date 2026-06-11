import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/canteen/ui/widgets/canteen_location_subtitle.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows dhbw.app attribution only for dhbw.app locations', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          LocalizationDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('de')],
        home: Scaffold(
          body: Column(
            children: [
              CanteenLocationSubtitle(
                location: CanteenLocations.defaultLocation,
              ),
              CanteenLocationSubtitle(
                location: CanteenLocation(
                  id: 'mannheim_mensaria_metropol',
                  name: 'DHBW Mannheim',
                  subtitle: 'Mensaria Metropol',
                  source: CanteenLocationSource.dhbwApp,
                  dhbwAppSite: 'MA',
                  dhbwAppMensaId: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Mensa Erzbergerstrasse'), findsOneWidget);
    expect(find.text('Mensaria Metropol'), findsOneWidget);
    expect(find.text('powered by dhbw.app'), findsOneWidget);
  });
}
