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

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await loadFilterStates();
  }

  Future<void> loadFilterStates() async {
    var allNames =
        await _scheduleEntryRepository.queryAllNamesOfScheduleEntries();

    var filteredNames = await _scheduleFilterRepository.queryAllHiddenNames();

    allNames.sort((s1, s2) => s1.compareTo(s2));

    filterStates = allNames.map((e) {
      var isFiltered = filteredNames.contains(e);
      return ScheduleEntryFilterState(!isFiltered, e);
    }).toList();

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

      _scheduleProvider.invalidateScheduleCache();
      _scheduleSource.fireScheduleSourceChanged();
    } catch (e) {
      throw FilterSaveException(e);
    }
  }
}

class ScheduleEntryFilterState {
  bool isDisplayed;
  String entryName;

  ScheduleEntryFilterState(this.isDisplayed, this.entryName);
}
