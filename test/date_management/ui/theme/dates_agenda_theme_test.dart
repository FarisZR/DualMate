import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/date_management/ui/theme/dates_agenda_theme.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registers approved light and dark agenda tokens', () {
    final light = ColorPalettes.buildTheme(
      AppTheme.Light,
    ).extension<DatesAgendaTheme>()!;
    final dark = ColorPalettes.buildTheme(
      AppTheme.Dark,
    ).extension<DatesAgendaTheme>()!;

    expect(light.examContainer, const Color(0xFFFBE9E9));
    expect(light.examForeground, const Color(0xFF3B0A0A));
    expect(light.examAccent, const Color(0xFFB3261E));
    expect(light.specialEventContainer, const Color(0xFFE9F2FF));
    expect(light.divider, const Color(0xFFD8D8D8));
    expect(dark.examContainer, const Color(0xFF3A1B1D));
    expect(dark.examAccent, const Color(0xFFFFB4AB));
    expect(dark.specialEventAccent, const Color(0xFFA9C7FF));
    expect(dark.divider, const Color(0xFF3A3A3A));
  });

  test('copyWith and lerp preserve all theme fields', () {
    final changed = DatesAgendaTheme.light.copyWith(
      examAccent: Colors.purple,
      divider: Colors.orange,
    );
    final midpoint = DatesAgendaTheme.light.lerp(DatesAgendaTheme.dark, 0.5);

    expect(changed.examAccent, Colors.purple);
    expect(changed.examContainer, DatesAgendaTheme.light.examContainer);
    expect(changed.divider, Colors.orange);
    expect(
      midpoint.examContainer,
      Color.lerp(
        DatesAgendaTheme.light.examContainer,
        DatesAgendaTheme.dark.examContainer,
        0.5,
      ),
    );
    expect(
      midpoint.specialEventForeground,
      Color.lerp(
        DatesAgendaTheme.light.specialEventForeground,
        DatesAgendaTheme.dark.specialEventForeground,
        0.5,
      ),
    );
  });

  test('maps domain categories to agenda or neutral Material tokens', () {
    const scheme = ColorScheme.light(
      surfaceContainerHigh: Color(0xFFEEEEEE),
      onSurface: Color(0xFF111111),
      onSurfaceVariant: Color(0xFF555555),
    );
    final exam = DatesAgendaTheme.light.colorsFor(
      ScheduleEntryType.Exam,
      scheme,
    );
    final special = DatesAgendaTheme.light.colorsFor(
      ScheduleEntryType.SpecialEvent,
      scheme,
    );
    final neutral = DatesAgendaTheme.light.colorsFor(
      ScheduleEntryType.PublicHoliday,
      scheme,
    );

    expect(exam.container, DatesAgendaTheme.light.examContainer);
    expect(special.accent, DatesAgendaTheme.light.specialEventAccent);
    expect(neutral.container, scheme.surfaceContainerHigh);
    expect(neutral.foreground, scheme.onSurface);
    expect(neutral.accent, scheme.onSurfaceVariant);
  });
}
