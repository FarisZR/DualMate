import 'dart:async';

import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/common/util/cancelable_mutex.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/date_management/business/date_entry_provider.dart';
import 'package:dualmate/date_management/business/important_event_organizer.dart';
import 'package:dualmate/date_management/business/rapla_important_events_provider.dart';
import 'package:dualmate/date_management/model/date_range.dart';
import 'package:dualmate/date_management/model/date_database.dart';
import 'package:dualmate/date_management/model/date_entry.dart';
import 'package:dualmate/date_management/model/date_search_parameters.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:dualmate/schedule/ui/viewmodels/schedule_freshness_gate.dart';
import 'package:dualmate/schedule/service/rapla/rapla_schedule_source.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';

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

  final Map<String, ScheduleFreshnessGate> _raplaFreshnessGates = {};
  final List<DateRange> _loadedRaplaWindows = <DateRange>[];
  DateRange? _nextRaplaWindow;
  DateRange? _cachedRaplaWindowEnd;
  bool _hasMoreRaplaPages = true;
  bool get hasMoreRaplaPages => _hasMoreRaplaPages;
  DateTime? _lastRaplaPageRequestAt;
  final Duration _raplaPageCooldown = const Duration(seconds: 30);
  DateTime? _lastNonHolidayEventEnd;
  bool _isLoadingNextRaplaPage = false;
  bool get isLoadingNextRaplaPage => _isLoadingNextRaplaPage;
  bool _nextRaplaPageFailed = false;
  bool get nextRaplaPageFailed => _nextRaplaPageFailed;

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
    _resetRaplaPaging();
    await _applyCachedRaplaWindows();
    var raplaEvents = await _readRaplaImportantEventsPage();
    _updateMutex.token.throwIfCancelled();

    if (raplaEvents != null) {
      _setImportantEvents(raplaEvents);
    }

    await _prefetchRaplaUntilFilled();

    _updateFailed = raplaEvents == null;
    if (updateFailed) {
      _cancelErrorInFuture();
    }

    notifyListeners("updateFailed");

    if (raplaEvents != null) {
      _refreshRaplaEventsInBackground();
    }
  }

  Future<List<ImportantEvent>?> _readRaplaImportantEventsPage() async {
    var raplaUrl = await _preferencesProvider.getRaplaUrl();
    _raplaUrlValid = RaplaScheduleSource.isValidUrl(raplaUrl);
    notifyListeners("raplaUrlValid");

    if (!_raplaUrlValid) {
      return null;
    }

    _nextRaplaWindow ??= _buildInitialRaplaWindow();
    var window = _nextRaplaWindow!;

    var loaded = await _loadRaplaWindow(
      window,
      _updateMutex.token,
      advanceWindow: true,
      refresh: false,
    );
    _refreshRaplaWindowInBackground(window);
    return loaded;
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

      await _refreshRaplaWindowsInBackground();
    } catch (_) {}
  }

  Future<void> _prefetchRaplaUntilFilled() async {
    for (var i = 0; i < 3; i++) {
      if (!_hasMoreRaplaPages) return;
      if (importantEventSections.isNotEmpty) return;

      await loadNextRaplaPage();
    }
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
    _updateLastNonHolidayEventEnd(events);
    _setImportantEventSections();
    notifyListeners("importantEvents");
  }

  void _appendImportantEvents(DateRange window, List<ImportantEvent> events) {
    _trackRaplaWindow(window);
    _importantEvents = _mergeImportantEvents(_importantEvents, events);
    _updateLastNonHolidayEventEnd(_importantEvents);
    _setImportantEventSections();
    notifyListeners("importantEvents");
  }

  void _replaceImportantEvents(DateRange window, List<ImportantEvent> events) {
    _trackRaplaWindow(window);
    _importantEvents = _mergeImportantEvents(_importantEvents, events);
    _updateLastNonHolidayEventEnd(_importantEvents);
    _setImportantEventSections();
    notifyListeners("importantEvents");
  }

  void _trackRaplaWindow(DateRange window) {
    if (_loadedRaplaWindows.any((existing) =>
        existing.start == window.start && existing.end == window.end)) {
      return;
    }
    _loadedRaplaWindows.add(window);
  }

  List<ImportantEvent> _mergeImportantEvents(
    List<ImportantEvent> existing,
    List<ImportantEvent> incoming,
  ) {
    var combined = <ImportantEvent>[...existing, ...incoming];
    var seenKeys = <String>{};
    var deduped = <ImportantEvent>[];

    for (var event in combined) {
      var key =
          '${event.title}-${event.type}-${event.start.toIso8601String()}-${event.end.toIso8601String()}';
      if (seenKeys.add(key)) {
        deduped.add(event);
      }
    }

    deduped.sort((a, b) => a.start.compareTo(b.start));
    return deduped;
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
      return;
    }

    updateDates();
  }

  void setShowFutureDates(bool value) {
    _showFutureDates = value;
    notifyListeners("showFutureDates");

    if (!_useDhMineForDates) {
      return;
    }

    updateDates();
  }

  void setShowOutOfStudyEvents(bool value) {
    _showOutOfStudyEvents = value;
    notifyListeners("showOutOfStudyEvents");
    if (!_useDhMineForDates) {
      return;
    }

    _setImportantEventSections();
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

  DateRange _buildInitialRaplaWindow() {
    var start = toStartOfDay(DateTime.now());
    return DateRange(start: start, end: _addMonths(start, 3));
  }

  DateRange _nextRaplaWindowFrom(DateRange current) {
    var nextStart = current.end;
    return DateRange(start: nextStart, end: _addMonths(nextStart, 3));
  }

  DateTime _maxRaplaEndDate() {
    var now = DateTime.now();
    var maxEnd = DateTime(
      now.year + 3,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );

    if (_lastNonHolidayEventEnd == null) {
      return maxEnd;
    }

    var nonHolidayCutoff = addDays(
      toStartOfDay(_lastNonHolidayEventEnd!),
      365,
    );

    return nonHolidayCutoff.isBefore(maxEnd) ? nonHolidayCutoff : maxEnd;
  }

  void _updateLastNonHolidayEventEnd(List<ImportantEvent> events) {
    DateTime? lastEnd;
    for (var event in events) {
      if (event.type == ScheduleEntryType.PublicHoliday) {
        continue;
      }
      if (lastEnd == null || event.end.isAfter(lastEnd)) {
        lastEnd = event.end;
      }
    }

    _lastNonHolidayEventEnd = lastEnd;
    _syncRaplaPagingLimit();
  }

  void _syncRaplaPagingLimit() {
    if (!_hasMoreRaplaPages) return;
    if (_nextRaplaWindow == null) return;
    if (!_nextRaplaWindow!.start.isBefore(_maxRaplaEndDate())) {
      _hasMoreRaplaPages = false;
      notifyListeners("hasMoreRaplaPages");
    }
  }

  void _resetRaplaPaging() {
    _loadedRaplaWindows.clear();
    _nextRaplaWindow = _buildInitialRaplaWindow();
    _nextRaplaPageFailed = false;
    _isLoadingNextRaplaPage = false;
    _cachedRaplaWindowEnd = null;
    _raplaFreshnessGates.clear();
    _hasMoreRaplaPages = true;
    _lastRaplaPageRequestAt = null;
    _lastNonHolidayEventEnd = null;
    notifyListeners("hasMoreRaplaPages");
  }

  Future<void> loadNextRaplaPage() async {
    if (_useDhMineForDates) return;
    if (_isLoadingNextRaplaPage) return;
    if (!_hasMoreRaplaPages) return;

    var now = DateTime.now();
    if (_lastRaplaPageRequestAt != null &&
        now.difference(_lastRaplaPageRequestAt!) < _raplaPageCooldown) {
      return;
    }
    _lastRaplaPageRequestAt = now;
    _nextRaplaWindow ??= _buildInitialRaplaWindow();
    var maxEnd = _maxRaplaEndDate();
    if (!_nextRaplaWindow!.start.isBefore(maxEnd)) {
      _hasMoreRaplaPages = false;
      notifyListeners("hasMoreRaplaPages");
      return;
    }

    _isLoadingNextRaplaPage = true;
    _nextRaplaPageFailed = false;
    notifyListeners("isLoadingNextRaplaPage");
    notifyListeners("nextRaplaPageFailed");

    var window = _nextRaplaWindow!;

    try {
      var beforeCount = importantEvents.length;
      var windowToLoad = window;
      if (windowToLoad.end.isAfter(maxEnd)) {
        windowToLoad = DateRange(start: windowToLoad.start, end: maxEnd);
      }
      var loaded = await _loadRaplaWindow(
        windowToLoad,
        CancellationToken(),
        advanceWindow: true,
        refresh: true,
      );
      if (loaded == null) {
        _nextRaplaPageFailed = true;
        notifyListeners("nextRaplaPageFailed");
      } else {
        var afterCount = importantEvents.length;
        if (afterCount == beforeCount) {
          _hasMoreRaplaPages = false;
          notifyListeners("hasMoreRaplaPages");
        }
      }
    } finally {
      _isLoadingNextRaplaPage = false;
      notifyListeners("isLoadingNextRaplaPage");
    }
  }

  Future<List<ImportantEvent>?> _loadRaplaWindow(
    DateRange window,
    CancellationToken token, {
    required bool advanceWindow,
    required bool refresh,
  }) async {
    try {
      var cached = await _raplaImportantEventsProvider.getCachedImportantEvents(
        toStartOfDay(window.start),
        toStartOfDay(window.end).add(const Duration(days: 1)),
      );

      if (cached.isNotEmpty) {
        _appendImportantEvents(window, cached);
      }

      if (refresh) {
        await _refreshRaplaWindow(window, token);
      }

      if (advanceWindow) {
        var next = _nextRaplaWindowFrom(window);
        var maxEnd = _maxRaplaEndDate();
        if (!next.start.isBefore(maxEnd)) {
          _hasMoreRaplaPages = false;
          notifyListeners("hasMoreRaplaPages");
        } else {
          _nextRaplaWindow = next;
        }
      }

      await _recordRaplaWindowEnd(window);

      return importantEvents;
    } on OperationCancelledException {
      return null;
    } on ScheduleQueryFailedException {
      return null;
    }
  }

  Future<void> _refreshRaplaWindow(
    DateRange window,
    CancellationToken token,
  ) async {
    if (!_isRaplaWindowStale(window, DateTime.now())) {
      return;
    }

    var updated = await _raplaImportantEventsProvider.refreshImportantEvents(
      toStartOfDay(window.start),
      toStartOfDay(window.end).add(const Duration(days: 1)),
      token,
    );

    if (updated != null) {
      _markRaplaWindowFetched(window, DateTime.now());
      var refreshed =
          await _raplaImportantEventsProvider.getCachedImportantEvents(
        toStartOfDay(window.start),
        toStartOfDay(window.end).add(const Duration(days: 1)),
      );
      _replaceImportantEvents(window, refreshed);
    }
  }

  Future<void> _recordRaplaWindowEnd(DateRange window) async {
    var cachedEnd =
        await _preferencesProvider.getRaplaImportantEventsWindowEnd();
    var currentEnd = cachedEnd == null || cachedEnd.isEmpty
        ? null
        : DateTime.tryParse(cachedEnd);

    var maxEnd = _maxRaplaEndDate();
    var clampedEnd = window.end.isAfter(maxEnd) ? maxEnd : window.end;

    if (currentEnd == null || clampedEnd.isAfter(currentEnd)) {
      await _preferencesProvider
          .setRaplaImportantEventsWindowEnd(clampedEnd.toIso8601String());
      _cachedRaplaWindowEnd = DateRange(
        start: _buildInitialRaplaWindow().start,
        end: clampedEnd,
      );
    }
  }

  void _refreshRaplaWindowInBackground(DateRange window) {
    Future.microtask(() async {
      await _refreshRaplaWindow(window, CancellationToken());
    });
  }

  bool _isRaplaWindowStale(DateRange window, DateTime now) {
    var gate = _raplaFreshnessGates[_raplaWindowKey(window)];
    return gate == null || gate.isStale(window.start, window.end, now);
  }

  void _markRaplaWindowFetched(DateRange window, DateTime now) {
    var key = _raplaWindowKey(window);
    var gate = _raplaFreshnessGates[key] ??= ScheduleFreshnessGate();
    gate.markFetched(window.start, window.end, now);
  }

  String _raplaWindowKey(DateRange window) {
    return '${window.start.toIso8601String()}_${window.end.toIso8601String()}';
  }

  Future<void> _refreshRaplaWindowsInBackground() async {
    var start = _buildInitialRaplaWindow().start;
    var end = _cachedRaplaWindowEnd?.end ?? start;
    var maxEnd = _maxRaplaEndDate();
    if (end.isAfter(maxEnd)) {
      end = maxEnd;
    }
    if (end.isBefore(start)) {
      end = start;
    }
    var windowStart = start;

    while (windowStart.isBefore(end) || windowStart.isAtSameMomentAs(end)) {
      var window =
          DateRange(start: windowStart, end: _addMonths(windowStart, 3));
      await _refreshRaplaWindow(window, CancellationToken());
      windowStart = window.end;
    }
  }

  Future<void> _applyCachedRaplaWindows() async {
    var cachedEnd =
        await _preferencesProvider.getRaplaImportantEventsWindowEnd();
    if (cachedEnd == null || cachedEnd.isEmpty) {
      return;
    }

    var parsed = DateTime.tryParse(cachedEnd);
    if (parsed == null) {
      return;
    }

    var start = _buildInitialRaplaWindow().start;
    var maxEnd = _maxRaplaEndDate();
    var end = parsed.isAfter(start) ? parsed : start;
    if (end.isAfter(maxEnd)) {
      end = maxEnd;
    }
    _cachedRaplaWindowEnd = DateRange(start: start, end: end);

    var windowStart = start;
    var lastWindowEnd = start;
    while (windowStart.isBefore(end) || windowStart.isAtSameMomentAs(end)) {
      var window =
          DateRange(start: windowStart, end: _addMonths(windowStart, 3));
      await _loadRaplaWindow(
        window,
        _updateMutex.token,
        advanceWindow: false,
        refresh: false,
      );
      lastWindowEnd = window.end;
      windowStart = window.end;
    }

    _nextRaplaWindow = DateRange(
      start: lastWindowEnd,
      end: _addMonths(lastWindowEnd, 3),
    );
    if (!_nextRaplaWindow!.start.isBefore(maxEnd)) {
      _hasMoreRaplaPages = false;
      notifyListeners("hasMoreRaplaPages");
    }
  }

  DateTime _addMonths(DateTime dateTime, int monthsToAdd) {
    return DateTime(
      dateTime.year,
      dateTime.month + monthsToAdd,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
    );
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
