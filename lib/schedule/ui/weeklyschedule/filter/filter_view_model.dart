import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';

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
  final ScheduleSourceProvider _scheduleSource;
  final ScheduleProvider _scheduleProvider;
  bool _initialized = false;

  List<ScheduleEntryFilterState> filterStates = [];

  FilterViewModel(
    this._scheduleEntryRepository,
    this._scheduleFilterRepository,
    this._scheduleSource,
    this._scheduleProvider,
  );

  static Future<void> preloadStates(
    ScheduleEntryRepository scheduleEntryRepository,
    ScheduleFilterRepository scheduleFilterRepository,
  ) async {
    if (_cachedStates != null) return;
    _cachedStatesFuture ??=
        _loadStates(scheduleEntryRepository, scheduleFilterRepository);
    _cachedStates = _cloneStates(await _cachedStatesFuture!);
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
    _cachedStates = _cloneStates(loadedStates);
    filterStates = _cloneStates(loadedStates);

    notifyIfMounted("filterStates");
  }

  Future<void> applyFilter() async {
    var allFilteredNames = filterStates
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

    try {
      await _scheduleFilterRepository.saveAllHiddenNames(allFilteredNames);
      _cachedStates = _cloneStates(filterStates);
      _cachedStatesFuture = null;

      _scheduleProvider.invalidateScheduleCache();
      _scheduleSource.fireScheduleSourceChanged();
    } catch (e) {
      throw FilterSaveException(e);
    }
  }

  static Future<List<ScheduleEntryFilterState>> _loadStates(
    ScheduleEntryRepository scheduleEntryRepository,
    ScheduleFilterRepository scheduleFilterRepository,
  ) async {
    final allNames =
        await scheduleEntryRepository.queryAllNamesOfScheduleEntries();
    final filteredNames = await scheduleFilterRepository.queryAllHiddenNames();

    allNames.sort((s1, s2) => s1.compareTo(s2));

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
