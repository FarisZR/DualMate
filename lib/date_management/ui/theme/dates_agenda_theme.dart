import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';

@immutable
class DatesAgendaCategoryColors {
  final Color container;
  final Color foreground;
  final Color accent;

  const DatesAgendaCategoryColors({
    required this.container,
    required this.foreground,
    required this.accent,
  });
}

@immutable
class DatesAgendaTheme extends ThemeExtension<DatesAgendaTheme> {
  final Color examContainer;
  final Color examForeground;
  final Color examAccent;
  final Color specialEventContainer;
  final Color specialEventForeground;
  final Color specialEventAccent;
  final Color divider;

  const DatesAgendaTheme({
    required this.examContainer,
    required this.examForeground,
    required this.examAccent,
    required this.specialEventContainer,
    required this.specialEventForeground,
    required this.specialEventAccent,
    required this.divider,
  });

  static const light = DatesAgendaTheme(
    examContainer: Color(0xFFFBE9E9),
    examForeground: Color(0xFF3B0A0A),
    examAccent: Color(0xFFB3261E),
    specialEventContainer: Color(0xFFE9F2FF),
    specialEventForeground: Color(0xFF0B1F3A),
    specialEventAccent: Color(0xFF2E5FA8),
    divider: Color(0xFFD8D8D8),
  );

  static const dark = DatesAgendaTheme(
    examContainer: Color(0xFF3A1B1D),
    examForeground: Color(0xFFFFDAD6),
    examAccent: Color(0xFFFFB4AB),
    specialEventContainer: Color(0xFF172A45),
    specialEventForeground: Color(0xFFD7E3FF),
    specialEventAccent: Color(0xFFA9C7FF),
    divider: Color(0xFF3A3A3A),
  );

  DatesAgendaCategoryColors colorsFor(
    ScheduleEntryType category,
    ColorScheme colorScheme,
  ) {
    switch (category) {
      case ScheduleEntryType.Exam:
        return DatesAgendaCategoryColors(
          container: examContainer,
          foreground: examForeground,
          accent: examAccent,
        );
      case ScheduleEntryType.SpecialEvent:
        return DatesAgendaCategoryColors(
          container: specialEventContainer,
          foreground: specialEventForeground,
          accent: specialEventAccent,
        );
      case ScheduleEntryType.Unknown:
      case ScheduleEntryType.Class:
      case ScheduleEntryType.Online:
      case ScheduleEntryType.PublicHoliday:
        return DatesAgendaCategoryColors(
          container: colorScheme.surfaceContainerHigh,
          foreground: colorScheme.onSurface,
          accent: colorScheme.onSurfaceVariant,
        );
    }
  }

  @override
  DatesAgendaTheme copyWith({
    Color? examContainer,
    Color? examForeground,
    Color? examAccent,
    Color? specialEventContainer,
    Color? specialEventForeground,
    Color? specialEventAccent,
    Color? divider,
  }) {
    return DatesAgendaTheme(
      examContainer: examContainer ?? this.examContainer,
      examForeground: examForeground ?? this.examForeground,
      examAccent: examAccent ?? this.examAccent,
      specialEventContainer:
          specialEventContainer ?? this.specialEventContainer,
      specialEventForeground:
          specialEventForeground ?? this.specialEventForeground,
      specialEventAccent: specialEventAccent ?? this.specialEventAccent,
      divider: divider ?? this.divider,
    );
  }

  @override
  DatesAgendaTheme lerp(covariant DatesAgendaTheme? other, double t) {
    if (other == null) return this;
    return DatesAgendaTheme(
      examContainer: Color.lerp(examContainer, other.examContainer, t)!,
      examForeground: Color.lerp(examForeground, other.examForeground, t)!,
      examAccent: Color.lerp(examAccent, other.examAccent, t)!,
      specialEventContainer: Color.lerp(
        specialEventContainer,
        other.specialEventContainer,
        t,
      )!,
      specialEventForeground: Color.lerp(
        specialEventForeground,
        other.specialEventForeground,
        t,
      )!,
      specialEventAccent: Color.lerp(
        specialEventAccent,
        other.specialEventAccent,
        t,
      )!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}
