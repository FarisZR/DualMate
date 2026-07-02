import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:flutter/foundation.dart';

/// Parses `--dart-define` values supplied through `flutter run` so the app can
/// skip onboarding and seed core settings during development.
///
/// Supported defines (all optional, only honored in debug builds):
///
/// * `SKIP_ONBOARDING` (`true`)  - marks the first start as completed.
/// * `SCHEDULE_SOURCE`           - one of `rapla`, `dualis`, `ical`,
///                                  `mannheim`, `none`.
/// * `RAPLA_URL`                 - Rapla schedule endpoint.
/// * `ICAL_URL`                  - iCal schedule endpoint.
/// * `MANNHEIM_ID`               - DHBW Mannheim schedule id.
/// * `CANTEEN_LOCATION_ID`       - one of [CanteenLocations.supported] ids.
///
/// Example:
///
/// ```sh
/// flutter run -d <device> \
///   --dart-define=SKIP_ONBOARDING=true \
///   --dart-define=SCHEDULE_SOURCE=rapla \
///   --dart-define=RAPLA_URL=https://rapla.dhbw.de/... \
///   --dart-define=CANTEEN_LOCATION_ID=karlsruhe_erzbergerstrasse
/// ```
class DebugStartupOverrides {
  final bool skipOnboarding;
  final ScheduleSourceType? scheduleSource;
  final String? raplaUrl;
  final String? icalUrl;
  final String? mannheimId;
  final String? canteenLocationId;

  const DebugStartupOverrides({
    this.skipOnboarding = false,
    this.scheduleSource,
    this.raplaUrl,
    this.icalUrl,
    this.mannheimId,
    this.canteenLocationId,
  });

  static const String _kSkipOnboarding = 'SKIP_ONBOARDING';
  static const String _kScheduleSource = 'SCHEDULE_SOURCE';
  static const String _kRaplaUrl = 'RAPLA_URL';
  static const String _kIcalUrl = 'ICAL_URL';
  static const String _kMannheimId = 'MANNHEIM_ID';
  static const String _kCanteenLocationId = 'CANTEEN_LOCATION_ID';

  /// Reads the compile-time `--dart-define` values. The result is always
  /// inactive in release builds because [apply] is guarded by [kDebugMode],
  /// and defaults to "no overrides" when no defines are provided.
  factory DebugStartupOverrides.fromEnvironment() {
    return DebugStartupOverrides(
      skipOnboarding: const bool.fromEnvironment(_kSkipOnboarding),
      scheduleSource: _parseScheduleSource(
        const String.fromEnvironment(_kScheduleSource),
      ),
      raplaUrl: _nonEmpty(const String.fromEnvironment(_kRaplaUrl)),
      icalUrl: _nonEmpty(const String.fromEnvironment(_kIcalUrl)),
      mannheimId: _nonEmpty(const String.fromEnvironment(_kMannheimId)),
      canteenLocationId: _nonEmpty(
        const String.fromEnvironment(_kCanteenLocationId),
      ),
    );
  }

  /// Whether any override was supplied and [apply] should run.
  bool get isActive =>
      skipOnboarding ||
      scheduleSource != null ||
      raplaUrl != null ||
      icalUrl != null ||
      mannheimId != null ||
      canteenLocationId != null;

  /// Resolves the effective schedule source type, preferring an explicit
  /// `SCHEDULE_SOURCE` define and otherwise inferring it from a URL define.
  ScheduleSourceType? get effectiveScheduleSource {
    if (scheduleSource != null) return scheduleSource;
    if (raplaUrl != null) return ScheduleSourceType.Rapla;
    if (icalUrl != null) return ScheduleSourceType.Ical;
    if (mannheimId != null) return ScheduleSourceType.Mannheim;
    return null;
  }

  /// Writes the overrides into the persisted preferences. Should only be
  /// called from a debug build path.
  Future<void> apply(PreferencesProvider preferencesProvider) async {
    if (skipOnboarding) {
      await preferencesProvider.setIsFirstStart(false);
    }

    if (raplaUrl != null) {
      await preferencesProvider.setRaplaUrl(raplaUrl!);
    }
    if (icalUrl != null) {
      await preferencesProvider.setIcalUrl(icalUrl!);
    }
    if (mannheimId != null) {
      await preferencesProvider.setMannheimScheduleId(mannheimId!);
    }

    final source = effectiveScheduleSource;
    if (source != null) {
      await preferencesProvider.setScheduleSourceType(source.index);
    }

    if (canteenLocationId != null) {
      final location = CanteenLocations.supportedFromId(canteenLocationId);
      if (location != null) {
        await preferencesProvider.setSelectedCanteenLocationId(location.id);
      }
    }
  }

  static String? _nonEmpty(String value) =>
      value.isEmpty ? null : value;

  static ScheduleSourceType? _parseScheduleSource(String value) {
    switch (value.toLowerCase()) {
      case 'rapla':
        return ScheduleSourceType.Rapla;
      case 'dualis':
        return ScheduleSourceType.Dualis;
      case 'ical':
        return ScheduleSourceType.Ical;
      case 'mannheim':
        return ScheduleSourceType.Mannheim;
      case 'none':
        return ScheduleSourceType.None;
      default:
        return null;
    }
  }
}
