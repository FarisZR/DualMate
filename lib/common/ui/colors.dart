import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/util/platform_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Color colorScheduleEntryPublicHoliday(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xffcbcbcb)
        : const Color(0xff515151);

Color colorScheduleEntryClass(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xffe63f3b)
        : const Color(0xffa52632);

Color colorScheduleEntryExam(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xfffdb531)
        : const Color(0xffb17f22);

Color colorScheduleEntryOnline(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xffAFC7EA)
        : const Color(0xff2659A6);

Color colorScheduleEntrySpecialEvent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xffc0e2ff)
        : const Color(0xff3d7fd6);

Color colorScheduleEntryUnknown(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xffcbcbcb)
        : const Color(0xff515151);

Color colorScheduleGridGridLines(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xffd8d8d8)
        : const Color(0xff3c3c3c);

Color colorScheduleInPastOverlay(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0x14000000)
        : const Color(0x2B000000);

Color colorCurrentTimeIndicator(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xffffa500)
        : const Color(0xffb37300);

Color colorOnboardingDecorationForeground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFA62828)
        : const Color(0xFFA62828);

Color colorOnboardingDecorationBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFC91A1A)
        : const Color(0xFFC91A1A);

Color colorSuccess(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFC91A1A)
        : const Color(0xFFC91A1A);

Color colorDailyScheduleTimeVerticalConnector() => Colors.grey;

Color colorSeparator() => Colors.grey;

Color colorNoConnectionBackground() => Colors.black87;

Color colorNoConnectionForeground() => Colors.white;

class ColorPalettes {
  ColorPalettes._();

  static ThemeData buildTheme(AppTheme theme) {
    if (theme == AppTheme.System) {
      theme = PlatformUtil.platformBrightness() == Brightness.light
          ? AppTheme.Light
          : AppTheme.Dark;
    }

    var isDark = theme == AppTheme.Dark;

    var brightness = isDark ? Brightness.dark : Brightness.light;

    var baseTheme = isDark ? ThemeData.dark() : ThemeData.light();
    var lightSurface = const Color(0xFFFFFFFF);
    var darkSurface = const Color(0xFF1E1E1E);
    var lightBackground = const Color(0xFFFFFFFF);
    var darkBackground = const Color(0xFF121212);

    var colorScheme = ColorScheme.fromSwatch(
      primarySwatch: ColorPalettes.main,
      brightness: brightness,
    ).copyWith(
      secondary: ColorPalettes.main[500],
      surface: isDark ? darkBackground : lightBackground,
      surfaceContainerHighest: isDark ? darkSurface : lightSurface,
      surfaceTint: Colors.transparent,
    );

    var themeData = baseTheme.copyWith(
      brightness: brightness,
      useMaterial3: true,
      applyElevationOverlayColor: false,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? darkBackground : lightBackground,
      canvasColor: isDark ? darkBackground : lightBackground,
      cardColor: isDark ? darkSurface : lightSurface,
      dialogBackgroundColor: isDark ? darkSurface : lightSurface,
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: isDark
            ? const Color(0xFF1B1B1B)
            : baseTheme.appBarTheme.backgroundColor,
        foregroundColor:
            isDark ? Colors.white : baseTheme.appBarTheme.foregroundColor,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: isDark
            ? const Color(0xFF1E1E1E)
            : baseTheme.inputDecorationTheme.fillColor,
        hintStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
        ),
        floatingLabelStyle: TextStyle(
          color: isDark ? Colors.white : colorScheme.primary,
        ),
        helperStyle: TextStyle(
          color: isDark ? Colors.white60 : Colors.black54,
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: isDark ? Colors.white30 : Colors.black26,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) return null;
            if (states.contains(WidgetState.selected)) {
              return isDark ? ColorPalettes.main[700] : ColorPalettes.main[600];
            }
            return null;
          },
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) return null;
            if (states.contains(WidgetState.selected)) {
              return isDark ? ColorPalettes.main[700] : ColorPalettes.main[600];
            }
            return null;
          },
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) return null;
            if (states.contains(WidgetState.selected)) {
              return isDark ? ColorPalettes.main[600] : ColorPalettes.main[500];
            }
            return isDark ? Colors.grey.shade400 : Colors.white;
          },
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) return null;
            if (states.contains(WidgetState.selected)) {
              return isDark ? const Color(0xFF3A3A3A) : const Color(0xFFBDBDBD);
            }
            return isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0);
          },
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkSurface : lightSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );

    return themeData.copyWith(
      snackBarTheme: themeData.snackBarTheme.copyWith(
        backgroundColor: isDark ? Color(0xff363635) : Color(0xfffafafa),
        contentTextStyle:
            (themeData.textTheme.bodyLarge ?? const TextStyle()).copyWith(
          color: isDark
              ? const Color(0xffe4e4e4)
              : themeData.textTheme.bodyLarge?.color,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ColorPalettes.main,
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4.0)),
          ),
        ),
      ),
    );
  }

  static const MaterialColor main = MaterialColor(0xffff061c, <int, Color>{
    050: Color(0xFFff838e),
    100: Color(0xFFff6a77),
    200: Color(0xFFff5160),
    300: Color(0xFFff3849),
    400: Color(0xFFff1f33),
    500: Color(0xffff061c),
    600: Color(0xFFe60519),
    700: Color(0xFFcc0516),
    800: Color(0xFFb30414),
    900: Color(0xFF990411),
  });

  static const MaterialColor secondary = MaterialColor(0xFFCECED0, <int, Color>{
    050: Color(0xFFF9F9F9),
    100: Color(0xFFF0F0F1),
    200: Color(0xFFE7E7E8),
    300: Color(0xFFDDDDDE),
    400: Color(0xFFD5D5D7),
    500: Color(0xFFCECED0),
    600: Color(0xFFC9C9CB),
    700: Color(0xFFC2C2C4),
    800: Color(0xFFBCBCBE),
    900: Color(0xFFB0B0B3),
  });

  static const MaterialColor secondaryAccent =
      MaterialColor(0xFFFFFFFF, <int, Color>{
    100: Color(0xFFFFFFFF),
    200: Color(0xFFFFFFFF),
    400: Color(0xFFFFFFFF),
    700: Color(0xFFEAEAFF),
  });
}
