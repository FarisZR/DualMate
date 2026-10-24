import 'dart:ui' as ui;

import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/ui/onboarding/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final c = KiwiContainer()..clear();
    final preferences = PreferencesProvider(
      PreferencesAccess(),
      SecureStorageAccess(),
    );
    c.registerInstance<PreferencesProvider>(preferences);
    c.registerInstance<ScheduleSourceProvider>(_Sources());
    c.registerInstance<DualisService>(_Dualis());
    c.registerInstance<CanteenLocationService>(
      CanteenLocationService(preferences),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  tearDown(() => KiwiContainer().clear());

  for (final theme in [AppTheme.Light, AppTheme.Dark]) {
    testWidgets(
      'onboarding paints a readable $theme surface before and after navigation',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final themeData = ColorPalettes.buildTheme(theme);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: themeData,
            localizationsDelegates: const [
              LocalizationDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: RepaintBoundary(key: boundary, child: const OnboardingPage()),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> expectSurface() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          // Empty space within the active page, below the radio fields.
          final offset = (600 * image.width + 195) * 4;
          final color = Color.fromARGB(
            255,
            pixels.getUint8(offset),
            pixels.getUint8(offset + 1),
            pixels.getUint8(offset + 2),
          );
          image.dispose();
          expect(color, themeData.scaffoldBackgroundColor);
        }

        await tester.runAsync(expectSurface);
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
        await tester.runAsync(expectSurface);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

class _Sources implements ScheduleSourceProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Dualis implements DualisService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
