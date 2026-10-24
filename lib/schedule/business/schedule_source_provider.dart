import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/logging/analytics.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/business/schedule_source_identity.dart';
import 'package:dualmate/schedule/service/dualis/dualis_schedule_source.dart';
import 'package:dualmate/schedule/service/error_report_schedule_source_decorator.dart';
import 'package:dualmate/schedule/service/ical/ical_schedule_source.dart';
import 'package:dualmate/schedule/service/invalid_schedule_source.dart';
import 'package:dualmate/schedule/service/isolate_schedule_source_decorator.dart';
import 'package:dualmate/schedule/service/mannheim/mannheim_course_service.dart';
import 'package:dualmate/schedule/service/rapla/rapla_schedule_source.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/filter_view_model.dart';
import 'package:kiwi/kiwi.dart';
import 'package:dualmate/schedule/data/timetable_repository.dart';
import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/service/combined_schedule_source.dart';
import 'package:mutex/mutex.dart';
import 'package:dualmate/common/util/cancellation_token.dart';

typedef OnDidChangeScheduleSource = void Function(
  ScheduleSource newSource,
  bool setupSuccess,
);

///
/// The ScheduleSourceProvider manages the ScheduleSource which is used by the
/// app. It provides functionality to hot swap the ScheduleSource implementation
/// while the app is running.
///
class ScheduleSourceProvider {
  final bool _appRunningInBackground;
  final PreferencesProvider _preferencesProvider;
  final ScheduleEntryRepository _scheduleEntryRepository;
  final ScheduleQueryInformationRepository _scheduleQueryInformationRepository;

  ScheduleSource _currentScheduleSource = InvalidScheduleSource();
  ScheduleSourceType _currentScheduleSourceType = ScheduleSourceType.None;
  String _currentSourceIdentity = 'none';
  int _sourceGeneration = 0;
  int configurationRevision = 0;
  final Mutex _configurationMutex = Mutex();
  final TimetableRepository? timetableRepository;
  List<TimetableConfiguration> timetables = const [];
  List<String> get activeSourceIdentities => timetables.isEmpty
      ? (currentSourceIdentity == 'none' ? [] : [currentSourceIdentity])
      : timetables.map((s) => s.id).toList();
  String identityForEntry(ScheduleEntry entry) => entry.sourceIdentity.isEmpty
      ? currentSourceIdentity
      : entry.sourceIdentity;

  ScheduleSource get currentScheduleSource => _currentScheduleSource;
  ScheduleSourceType get currentScheduleSourceType =>
      _currentScheduleSourceType;
  String get currentSourceIdentity => _currentSourceIdentity;
  int get sourceGeneration => _sourceGeneration;

  List<OnDidChangeScheduleSource> _onDidChangeScheduleSourceCallbacks = [];

  ScheduleSourceProvider(
    this._preferencesProvider,
    this._appRunningInBackground,
    this._scheduleEntryRepository,
    this._scheduleQueryInformationRepository, {
    this.timetableRepository,
  });

  Future<bool> setupScheduleSource() async {
    if (timetableRepository != null) {
      final snapshot = await timetableRepository!.loadSnapshot();
      timetables = snapshot.sources;
      configurationRevision = snapshot.revision;
      final sources = <String, ScheduleSource>{};
      for (final config in timetables) {
        sources[config.id] = await createSource(config);
      }
      _currentScheduleSource = sources.isEmpty
          ? InvalidScheduleSource()
          : CombinedScheduleSource(sources);
      _currentScheduleSourceType = timetables.isEmpty
          ? ScheduleSourceType.None
          : timetables.first.type;
      final identity = timetables.isEmpty ? 'none' : timetables.first.id;
      if (_currentSourceIdentity != identity) {
        _sourceGeneration++;
      }
      _currentSourceIdentity = identity;
      for (final callback in _onDidChangeScheduleSourceCallbacks) {
        callback(_currentScheduleSource, didSetupCorrectly());
      }
      return didSetupCorrectly();
    }
    var scheduleSourceType = await _getScheduleSourceType();

    ScheduleSource scheduleSource = InvalidScheduleSource();

    final initializer = {
      ScheduleSourceType.Dualis: () async => await _dualisScheduleSource(),
      ScheduleSourceType.Rapla: () async => await _raplaScheduleSource(),
      ScheduleSourceType.Ical: () async => await _icalScheduleSource(),
      ScheduleSourceType.Mannheim: () async => await _mannheimScheduleSource(),
    };

    var init = initializer[scheduleSourceType];
    if (init != null) {
      scheduleSource = await init();
    }

    _currentScheduleSource = scheduleSource;
    _currentScheduleSourceType = didSetupCorrectly()
        ? scheduleSourceType
        : ScheduleSourceType.None;
    final nextIdentity = didSetupCorrectly()
        ? await _configuredSourceIdentity(scheduleSourceType)
        : 'none';
    if (_currentSourceIdentity != nextIdentity) {
      _currentSourceIdentity = nextIdentity;
      _sourceGeneration += 1;
    }

    var success = didSetupCorrectly();

    _onDidChangeScheduleSourceCallbacks.forEach((element) {
      element(scheduleSource, success);
    });

    return success;
  }

  Future<ScheduleSourceType> _getScheduleSourceType() async {
    var type = await _preferencesProvider.getScheduleSourceType();

    var scheduleSourceType = ScheduleSourceType.values[type];

    return scheduleSourceType;
  }

  Future<ScheduleSource> _dualisScheduleSource() async {
    var dualis = DualisScheduleSource(KiwiContainer().resolve());

    var credentials = await _preferencesProvider.loadDualisCredentials();

    if (credentials.allFieldsFilled()) {
      dualis.setLoginCredentials(credentials);
      FilterViewModel.invalidateCache();
      return ErrorReportScheduleSourceDecorator(dualis);
    } else {
      return InvalidScheduleSource();
    }
  }

  Future<ScheduleSource> _raplaScheduleSource() async {
    var raplaUrl = await _preferencesProvider.getRaplaUrl();

    var rapla = RaplaScheduleSource();
    var urlValid = RaplaScheduleSource.isValidUrl(raplaUrl);

    if (urlValid) {
      rapla.setEndpointUrl(raplaUrl);

      ScheduleSource source = ErrorReportScheduleSourceDecorator(rapla);

      if (!_appRunningInBackground) {
        source = IsolateScheduleSourceDecorator(source);
      }
      return source;
    }

    return InvalidScheduleSource();
  }

  Future<ScheduleSource> _icalScheduleSource() async {
    var url = await _preferencesProvider.getIcalUrl();
    return _scheduleSourceFromIcalUrl(url);
  }

  Future<ScheduleSource> _mannheimScheduleSource() async {
    var url = await _preferencesProvider.getIcalUrl();
    if (!MannheimCourseService.isMannheimProfileUrl(url)) {
      return InvalidScheduleSource();
    }

    return _scheduleSourceFromIcalUrl(url);
  }

  Future<ScheduleSource> _scheduleSourceFromIcalUrl(String url) async {
    var ical = IcalScheduleSource();
    ical.setIcalUrl(url);

    if (ical.canQuery()) {
      ScheduleSource source = ErrorReportScheduleSourceDecorator(ical);

      if (!_appRunningInBackground) {
        source = IsolateScheduleSourceDecorator(source);
      }
      return source;
    }

    return InvalidScheduleSource();
  }

  Future<String> _configuredSourceIdentity(ScheduleSourceType type) async {
    final configuredValue = switch (type) {
      ScheduleSourceType.Rapla => await _preferencesProvider.getRaplaUrl(),
      ScheduleSourceType.Ical => await _preferencesProvider.getIcalUrl(),
      ScheduleSourceType.Mannheim =>
        await _preferencesProvider.getMannheimScheduleId(),
      ScheduleSourceType.Dualis =>
        (await _preferencesProvider.loadDualisCredentials()).username,
      ScheduleSourceType.None => '',
    };
    return ScheduleSourceIdentity.create(type, configuredValue);
  }

  bool wouldChangeTo(ScheduleSourceType type, String configuredValue) {
    final String nextIdentity;
    if (type == ScheduleSourceType.None || configuredValue.trim().isEmpty) {
      nextIdentity = 'none';
    } else {
      nextIdentity = ScheduleSourceIdentity.create(type, configuredValue);
    }
    return nextIdentity != _currentSourceIdentity;
  }

  /// Onboarding stores the Rapla URL first and defers full source setup plus
  /// cache clearing to post-onboarding initialization. Other setup flows run
  /// after onboarding and therefore keep the default immediate setup behavior.
  Future<void> setupForRapla(
    String url, {
    bool clearCachedEntries = true,
    bool setupSource = true,
  }) async {
    await _preferencesProvider.setRaplaUrl(url);
    await _preferencesProvider.setScheduleSourceType(
      ScheduleSourceType.Rapla.index,
    );
    await _replacePrimary(ScheduleSourceType.Rapla, url, url);

    if (clearCachedEntries) {
      await _clearEntryCache();
    }
    if (setupSource) {
      await setupScheduleSource();
    }

    await analytics.setUserProperty(name: "schedule_source", value: "Rapla");
  }

  Future<void> setupForDualis() async {
    await _preferencesProvider.setScheduleSourceType(
      ScheduleSourceType.Dualis.index,
    );
    final username =
        (await _preferencesProvider.loadDualisCredentials()).username;
    await _replacePrimary(ScheduleSourceType.Dualis, username, username);

    await _clearEntryCache();
    await setupScheduleSource();

    await analytics.setUserProperty(name: "schedule_source", value: "Dualis");
  }

  Future<void> setupForIcal(String url) async {
    await _preferencesProvider.setIcalUrl(url);
    await _preferencesProvider.setScheduleSourceType(
      ScheduleSourceType.Ical.index,
    );
    await _replacePrimary(ScheduleSourceType.Ical, url, url);

    await _clearEntryCache();
    await setupScheduleSource();

    await analytics.setUserProperty(name: "schedule_source", value: "Ical");
  }

  Future<void> setupForMannheim(MannheimCourse selectedCourse) async {
    await _preferencesProvider.setMannheimScheduleId(selectedCourse.scheduleId);
    await _preferencesProvider.setIcalUrl(selectedCourse.icalUrl);
    await _preferencesProvider.setScheduleSourceType(
      ScheduleSourceType.Mannheim.index,
    );
    await _replacePrimary(
      ScheduleSourceType.Mannheim,
      selectedCourse.icalUrl,
      selectedCourse.scheduleId,
    );

    await _clearEntryCache();
    await setupScheduleSource();

    await analytics.setUserProperty(
      name: "schedule_source",
      value: "DHBW Mannheim",
    );
  }

  bool didSetupCorrectly() {
    return !(_currentScheduleSource is InvalidScheduleSource);
  }

  Future<ScheduleSource> createSource(TimetableConfiguration config) async {
    if (config.type == ScheduleSourceType.Dualis)
      return _dualisScheduleSource();
    if (config.type == ScheduleSourceType.Rapla) {
      if (!RaplaScheduleSource.isValidUrl(config.value))
        return InvalidScheduleSource();
      final rapla = RaplaScheduleSource()..setEndpointUrl(config.value);
      ScheduleSource source = ErrorReportScheduleSourceDecorator(rapla);
      return _appRunningInBackground
          ? source
          : IsolateScheduleSourceDecorator(source);
    }
    return _scheduleSourceFromIcalUrl(config.value);
  }

  Future<void> saveTimetables(
    List<TimetableConfiguration> configurations,
  ) async {
    await _configurationMutex.protect(() async {
      _sourceGeneration++;
      await timetableRepository!.save(configurations);
    });
    FilterViewModel.invalidateCache();
    await setupScheduleSource();
  }

  Future<T> withConfiguration<T>(int generation, Future<T> Function() action) =>
      _configurationMutex.protect(() async {
        if (generation != sourceGeneration) throw OperationCancelledException();
        return await action();
      });

  Future<void> _replacePrimary(
    ScheduleSourceType type,
    String value,
    String identityValue,
  ) async {
    if (timetableRepository == null) return;
    final existing = await timetableRepository!.load();
    final id = ScheduleSourceIdentity.create(type, identityValue);
    if (existing.isNotEmpty && existing.first.id == id) return;
    final primary = TimetableConfiguration(
      id: id,
      label: TimetableRepository.labelFor(type, value),
      type: type,
      value: value,
      includeAll: true,
    );
    await timetableRepository!.save([
      primary,
      ...existing.skip(1).where((s) => s.id != id),
    ]);
  }

  /// Replaces a validated configured source only for the opt-in performance
  /// fixture. Production setup continues to use [setupScheduleSource].
  void usePerformanceFixtureSource(ScheduleSource source) {
    _currentScheduleSource = source;
    _onDidChangeScheduleSourceCallbacks.forEach((element) {
      element(source, true);
    });
  }

  void addDidChangeScheduleSourceCallback(OnDidChangeScheduleSource callback) {
    _onDidChangeScheduleSourceCallbacks.add(callback);
  }

  void removeDidChangeScheduleSourceCallback(
    OnDidChangeScheduleSource callback,
  ) {
    _onDidChangeScheduleSourceCallbacks.remove(callback);
  }

  Future<void> _clearEntryCache() async {
    var scheduleEntries = _scheduleEntryRepository.deleteAllScheduleEntries();
    var queryInformation = _scheduleQueryInformationRepository
        .deleteAllQueryInformation();

    await Future.wait([scheduleEntries, queryInformation]);
  }

  /// Clears all cached schedule entries and query information. Used when
  /// replaying onboarding so stale data from a prior configuration does not
  /// linger through the deferred onboarding save path.
  Future<void> clearScheduleCache() async {
    await _clearEntryCache();
  }

  void fireScheduleSourceChanged() {
    _onDidChangeScheduleSourceCallbacks.forEach((element) {
      element(currentScheduleSource, true);
    });
  }
}
