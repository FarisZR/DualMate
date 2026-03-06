import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:flutter/foundation.dart';

class FilterValidationException implements Exception {
  final String message;

  FilterValidationException(this.message);

  @override
  String toString() => 'FilterValidationException: $message';
}

class FilterSaveException implements Exception {
  final Object innerException;

  FilterSaveException(this.innerException);

  @override
  String toString() => 'FilterSaveException: $innerException';
}

class FilterViewModel extends BaseViewModel {
  static List<ScheduleEntryFilterState>? _cachedStates;
  static Future<List<ScheduleEntryFilterState>>? _cachedStatesFuture;

  final ScheduleEntryRepository _scheduleEntryRepository;
  final ScheduleFilterRepository _scheduleFilterRepository;
  bool _initialized = false;

  List<ScheduleEntryFilterState> filterStates = [];

  FilterViewModel(
    this._scheduleEntryRepository,
    this._scheduleFilterRepository,
  );

  static Future<void> preloadStates(
    ScheduleEntryRepository scheduleEntryRepository,
    ScheduleFilterRepository scheduleFilterRepository,
  ) async {
    if (_cachedStates != null) return;
    _cachedStatesFuture ??=
        _loadStates(scheduleEntryRepository, scheduleFilterRepository);
    final loadedStates = await _cachedStatesFuture!;
    if (loadedStates.isEmpty) {
      _cachedStates = null;
      _cachedStatesFuture = null;
      return;
    }
    _cachedStates = _cloneStates(loadedStates);
  }

  static bool get hasCachedStates => _cachedStates != null;

  /// Clears the static cache so the next load reflects latest repository data.
  static void invalidateCache() {
    _cachedStates = null;
    _cachedStatesFuture = null;
  }

  @visibleForTesting
  static void resetCachedStateForTesting() {
    invalidateCache();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await loadFilterStates();
  }

  Future<void> loadFilterStates() async {
    final cached = _cachedStates;
    if (cached != null) {
      filterStates = _cloneStates(cached);
      notifyIfMounted("filterStates");
      return;
    }

    _cachedStatesFuture ??=
        _loadStates(_scheduleEntryRepository, _scheduleFilterRepository);
    final loadedStates = await _cachedStatesFuture!;
    if (loadedStates.isEmpty) {
      _cachedStates = null;
      _cachedStatesFuture = null;
    } else {
      _cachedStates = _cloneStates(loadedStates);
    }
    filterStates = _cloneStates(loadedStates);

    notifyIfMounted("filterStates");
  }

  Future<bool> applyFilter() async {
    final allFilteredNames = filterStates
        .where((element) => !element.isDisplayed)
        .map((e) => e.entryName)
        .toList();

    if (allFilteredNames.any((name) => name.trim().isEmpty)) {
      throw FilterValidationException("Filter entry names must not be empty");
    }

    final uniqueNames = allFilteredNames.toSet();
    if (uniqueNames.length != allFilteredNames.length) {
      throw FilterValidationException("Filter entry names must be unique");
    }

    final previousHiddenNames = _cachedStates
            ?.where((state) => !state.isDisplayed)
            .map((state) => state.entryName)
            .toSet() ??
        const <String>{};
    if (setEquals(previousHiddenNames, uniqueNames)) {
      return false;
    }

    try {
      await _scheduleFilterRepository.saveAllHiddenNames(allFilteredNames);
      _cachedStates = _cloneStates(filterStates);
      _cachedStatesFuture = null;
      return true;
    } catch (e) {
      throw FilterSaveException(e);
    }
  }

  static Future<List<ScheduleEntryFilterState>> _loadStates(
    ScheduleEntryRepository scheduleEntryRepository,
    ScheduleFilterRepository scheduleFilterRepository,
  ) async {
    final allNamesFuture =
        scheduleEntryRepository.queryAllNamesOfScheduleEntries();
    final filteredNamesFuture = scheduleFilterRepository.queryAllHiddenNames();
    final allNames = List<String>.from(await allNamesFuture);
    final filteredNames = (await filteredNamesFuture).toSet();

    return allNames.map((e) {
      final isFiltered = filteredNames.contains(e);
      return ScheduleEntryFilterState(!isFiltered, e);
    }).toList();
  }

  static List<ScheduleEntryFilterState> _cloneStates(
    List<ScheduleEntryFilterState> source,
  ) {
    return source
        .map((state) => ScheduleEntryFilterState(
              state.isDisplayed,
              state.entryName,
            ))
        .toList();
  }
}

class ScheduleEntryFilterState {
  bool isDisplayed;
  String entryName;

  ScheduleEntryFilterState(this.isDisplayed, this.entryName);
}
