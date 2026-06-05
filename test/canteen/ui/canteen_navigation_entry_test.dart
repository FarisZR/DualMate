import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/canteen/data/canteen_meal_repository.dart';
import 'package:dualmate/canteen/service/canteen_scraper.dart';
import 'package:dualmate/canteen/service/dhbw_app_canteen_source.dart';
import 'package:dualmate/canteen/service/open_mensa_canteen_source.dart';
import 'package:dualmate/canteen/ui/canteen_navigation_entry.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';

import '../test_canteen_location_service.dart';

void main() {
  setUp(() {
    KiwiContainer().clear();
  });

  tearDown(() {
    KiwiContainer().clear();
  });

  testWidgets('canteen app bar actions use overflow menu', (tester) async {
    KiwiContainer().registerInstance<CanteenProvider>(_FakeCanteenProvider());
    KiwiContainer().registerInstance<CanteenLocationService>(
      TestCanteenLocationService(),
    );

    final entry = CanteenNavigationEntry();
    entry.initViewModel();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          LocalizationDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('de')],
        home: Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(actions: entry.appBarActions(context)),
            );
          },
        ),
      ),
    );

    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsNothing);
    expect(find.byIcon(Icons.restaurant), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Select canteen'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
  });
}

class _FakeCanteenProvider extends CanteenProvider {
  _FakeCanteenProvider()
    : super(
        CanteenMealRepository(_FakeDatabaseAccess()),
        TestCanteenLocationService(),
        CanteenScraper(),
        OpenMensaCanteenSource(),
        DhbwAppCanteenSource(),
      );
}

class _FakeDatabaseAccess implements DatabaseAccess {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
