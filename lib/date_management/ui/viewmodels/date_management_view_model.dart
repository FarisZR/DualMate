import 'dart:async';

import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/common/util/cancelable_mutex.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/date_management/business/date_entry_provider.dart';
import 'package:dualmate/date_management/business/important_event_organizer.dart';
import 'package:dualmate/date_management/business/rapla_important_events_provider.dart';
import 'package:dualmate/date_management/model/date_database.dart';
import 'package:dualmate/date_management/model/date_entry.dart';
import 'package:dualmate/date_management/model/date_search_parameters.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:dualmate/schedule/service/rapla/rapla_schedule_source.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

class DateManagementViewModel extends BaseViewModel {
  final DateEntryProvider _dateEntryProvider;
  final PreferencesProvider _preferencesProvider;
  final RaplaImportantEventsProvider _raplaImportantEventsProvider;
  final ImportantEventOrganizer _importantEventOrganizer =
      ImportantEventOrganizer();

  final List<DateDatabase> _allDateDatabases = [
    DateDatabase("BWL-Bank", "Termine_BWL_Bank"),
    DateDatabase("Immobilienwirtschaft", "Termine_BWL_Immo"),
    DateDatabase(
        "Dienstleistungsmanagement Consulting & Sales", "Termine_DLM_Consult"),
    DateDatabase("Dienstleistungsmanagement Logistik", "Termine_DLM_Logistik"),
    DateDatabase("Campus Horb Informatik", "Termine_Horb_INF"),
    DateDatabase("Campus Horb Maschinenbau", "Termine_Horb_MB"),
    DateDatabase("International Business", "Termine_IB"),
    DateDatabase("Informatik", "Termine_Informatik"),
    DateDatabase("MUK (DLM - C&S, LogM, MUK)", "Termine_MUK"),
    DateDatabase("SO_GuO (Abweichungen und Ergänzungen zum Vorlesungsplan)",
        "Termine_SO_GuO"),
    DateDatabase("Wirtschaftsingenieurwesen", "Termine_WIW"),
  ];
  List<DateDatabase> get allDateDatabases => _allDateDatabases;

  final CancelableMutex _updateMutex = CancelableMutex();

  Timer? _errorResetTimer;

  final List<String> _years = [];
  List<String> get years => _years;

  late String _currentSelectedYear;
  String get currentSelectedYear => _currentSelectedYear;

  List<DateEntry> _allDates = <DateEntry>[];
  List<DateEntry> get allDates => _allDates;

  List<DateEntry> get exportEntries {
    if (_useDhMineForDates) {
      return _allDates;
    }

    return _visibleImportantEvents
        .map((event) => DateEntry(
              description: event.title,
              year: event.start.year.toString(),
              comment: '',
              databaseName: 'Rapla',
              start: event.start,
              end: event.end,
              room: '',
            ))
        .toList(growable: false);
  }

  List<ImportantEvent> get _visibleImportantEvents {
    var events = <ImportantEvent>[];
    var seenKeys = <String>{};

    for (var section in _importantEventSections) {
      if (section.header != null) {
        _addEvent(events, seenKeys, section.header!);
      }
      for (var event in section.events) {
        _addEvent(events, seenKeys, event);
      }
    }

    return events;
  }

  List<ImportantEvent> _importantEvents = <ImportantEvent>[];
  List<ImportantEvent> get importantEvents => _importantEvents;

  List<ImportantEventSection> _importantEventSections =
      <ImportantEventSection>[];
  List<ImportantEventSection> get importantEventSections =>
      _importantEventSections;

  bool _showPassedDates = false;
  bool get showPassedDates => _showPassedDates;

  bool _showFutureDates = true;
  bool get showFutureDates => _showFutureDates;

  bool _showOutOfStudyEvents = false;
  bool get showOutOfStudyEvents => _showOutOfStudyEvents;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isReloadingPreferences = false;

  bool _useDhMineForDates = false;
  bool get useDhMineForDates => _useDhMineForDates;

  bool _raplaUrlValid = true;
  bool get raplaUrlValid => _raplaUrlValid;

  late DateDatabase _currentDateDatabase;
  DateDatabase get currentDateDatabase => _currentDateDatabase;

  int _dateEntriesKeyIndex = 0;
  int get dateEntriesKeyIndex => _dateEntriesKeyIndex;

  bool _updateFailed = false;
  bool get updateFailed => _updateFailed;

  DateSearchParameters get dateSearchParameters => DateSearchParameters(
        showPassedDates,
        showFutureDates,
        currentSelectedYear,
        currentDateDatabase.id,
      );

  DateManagementViewModel(
    this._dateEntryProvider,
    this._preferencesProvider,
    this._raplaImportantEventsProvider,
  ) {
    _buildYearsArray();
    _currentSelectedYear = DateTime.now().year.toString();
    _currentDateDatabase = _allDateDatabases.first;
    _loadDefaultSelection();
  }

  void _buildYearsArray() {
    for (var i = 2017; i < DateTime.now().year + 3; i++) {
      _years.add(i.toString());
    }
  }

  Future<void> updateDates() async {
    await _updateMutex.acquireAndCancelOther();

    try {
      _isLoading = true;
      notifyListeners("isLoading");

      if (_useDhMineForDates) {
        await _doUpdateDates();
      } else {
        await _doUpdateRaplaEvents();
      }
    } catch (_) {
    } finally {
      _isLoading = false;
      _updateMutex.release();
      notifyListeners("isLoading");
    }
  }

  Future<void> reloadUseDhMineSetting() async {
    if (_isReloadingPreferences) return;
    _isReloadingPreferences = true;

    try {
      var storedValue = await _preferencesProvider.getUseDhMineForDates();
      if (storedValue != _useDhMineForDates) {
        _useDhMineForDates = storedValue;
        notifyListeners("useDhMineForDates");
        await updateDates();
      }
    } finally {
      _isReloadingPreferences = false;
    }
  }

  Future<void> _doUpdateDates() async {
    var cachedDateEntries = await _readCachedDateEntries();
    _updateMutex.token.throwIfCancelled();
    _setAllDates(cachedDateEntries);

    var loadedDateEntries = await _readUpdatedDateEntries();
    _updateMutex.token.throwIfCancelled();

    if (loadedDateEntries != null) {
      _setAllDates(loadedDateEntries);
    }

    _updateFailed = loadedDateEntries == null;
    if (updateFailed) {
      _cancelErrorInFuture();
    }

    notifyListeners("updateFailed");
  }

  Future<void> _doUpdateRaplaEvents() async {
    var raplaEvents = await _readRaplaImportantEvents();
    _updateMutex.token.throwIfCancelled();

    if (raplaEvents != null) {
      _setImportantEvents(raplaEvents);
    }

    _updateFailed = raplaEvents == null;
    if (updateFailed) {
      _cancelErrorInFuture();
    }

    notifyListeners("updateFailed");

    if (raplaEvents != null) {
      _refreshRaplaEventsInBackground();
    }
  }

  Future<List<ImportantEvent>?> _readRaplaImportantEvents() async {
    var raplaUrl = await _preferencesProvider.getRaplaUrl();
    _raplaUrlValid = RaplaScheduleSource.isValidUrl(raplaUrl);
    notifyListeners("raplaUrlValid");

    if (!_raplaUrlValid) {
      return null;
    }

    var now = DateTime.now();
    var start =
        _showPassedDates ? DateTime(now.year - 3, now.month, now.day) : now;
    var end =
        _showFutureDates ? DateTime(now.year + 3, now.month, now.day) : now;

    if (start.isAfter(end)) {
      return [];
    }

    try {
      var events = await _raplaImportantEventsProvider.getImportantEvents(
        toStartOfDay(start),
        toStartOfDay(end).add(const Duration(days: 1)),
        _updateMutex.token,
      );

      return events;
    } on OperationCancelledException {
    } on ScheduleQueryFailedException {}

    return null;
  }

  Future<void> _refreshRaplaEventsInBackground() async {
    try {
      if (_updateMutex.isLocked) {
        return;
      }

      var raplaUrl = await _preferencesProvider.getRaplaUrl();
      if (!RaplaScheduleSource.isValidUrl(raplaUrl)) {
        return;
      }

      var now = DateTime.now();
      var start =
          _showPassedDates ? DateTime(now.year - 3, now.month, now.day) : now;
      var end =
          _showFutureDates ? DateTime(now.year + 3, now.month, now.day) : now;

      if (start.isAfter(end)) {
        return;
      }

      var events = await _raplaImportantEventsProvider.getImportantEvents(
        toStartOfDay(start),
        toStartOfDay(end).add(const Duration(days: 1)),
        CancellationToken(),
        forceRefresh: true,
      );

      _setImportantEvents(events);
    } catch (_) {}
  }

  Future<List<DateEntry>?> _readUpdatedDateEntries() async {
    try {
      var loadedDateEntries = await _dateEntryProvider.getDateEntries(
        dateSearchParameters,
        _updateMutex.token,
      );
      return loadedDateEntries;
    } on OperationCancelledException {
    } on ServiceRequestFailed {}

    return null;
  }

  Future<List<DateEntry>> _readCachedDateEntries() async {
    var cachedDateEntries = await _dateEntryProvider.getCachedDateEntries(
      dateSearchParameters,
    );
    return cachedDateEntries;
  }

  void _setAllDates(List<DateEntry> dateEntries) {
    _allDates = dateEntries;
    _dateEntriesKeyIndex++;

    notifyListeners("allDates");
  }

  void _setImportantEvents(List<ImportantEvent> events) {
    _importantEvents = events;
    _setImportantEventSections();
    notifyListeners("importantEvents");
  }

  void _setImportantEventSections() {
    _importantEventSections = _importantEventOrganizer.buildSections(
      _importantEvents,
      includeOutsideStudy: _showOutOfStudyEvents,
    );
    notifyListeners("importantEventSections");
  }

  void _addEvent(
    List<ImportantEvent> events,
    Set<String> seenKeys,
    ImportantEvent event,
  ) {
    var key =
        '${event.title}-${event.type}-${event.start.toIso8601String()}-${event.end.toIso8601String()}';
    if (seenKeys.add(key)) {
      events.add(event);
    }
  }

  void setShowPassedDates(bool value) {
    _showPassedDates = value;
    notifyListeners("showPassedDates");

    if (!_useDhMineForDates) {
      updateDates();
    }
  }

  void setShowFutureDates(bool value) {
    _showFutureDates = value;
    notifyListeners("showFutureDates");

    if (!_useDhMineForDates) {
      updateDates();
    }
  }

  void setShowOutOfStudyEvents(bool value) {
    _showOutOfStudyEvents = value;
    notifyListeners("showOutOfStudyEvents");
    if (!_useDhMineForDates) {
      _setImportantEventSections();
    }
  }

  void setCurrentDateDatabase(DateDatabase database) {
    _currentDateDatabase = database;
    notifyListeners("currentDateDatabase");

    _preferencesProvider.setLastViewedDateEntryDatabase(database.id);
  }

  void setCurrentSelectedYear(String year) {
    _currentSelectedYear = year;
    notifyListeners("currentSelectedYear");

    _preferencesProvider.setLastViewedDateEntryYear(year);
  }

  void _loadDefaultSelection() async {
    _useDhMineForDates = await _preferencesProvider.getUseDhMineForDates();
    notifyListeners("useDhMineForDates");

    var database = await _preferencesProvider.getLastViewedDateEntryDatabase();

    bool didSetDatabase = false;
    for (var db in allDateDatabases) {
      if (db.id == database) {
        setCurrentDateDatabase(db);
        didSetDatabase = true;
      }
    }

    if (!didSetDatabase) {
      setCurrentDateDatabase(allDateDatabases[0]);
    }

    var year = await _preferencesProvider.getLastViewedDateEntryYear();
    if (years.contains(year)) {
      setCurrentSelectedYear(year);
    } else {
      setCurrentSelectedYear(_currentSelectedYear);
    }

    await updateDates();
  }

  void _cancelErrorInFuture() async {
    _errorResetTimer?.cancel();

    _errorResetTimer = Timer(
      const Duration(seconds: 5),
      () {
        _updateFailed = false;
        notifyListeners("updateFailed");
      },
    );
  }
}
