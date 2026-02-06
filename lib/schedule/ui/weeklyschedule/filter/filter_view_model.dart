import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:kiwi/kiwi.dart';

class FilterViewModel extends BaseViewModel {
  final ScheduleEntryRepository _scheduleEntryRepository;
  final ScheduleFilterRepository _scheduleFilterRepository;
  final ScheduleSourceProvider _scheduleSource;

  List<ScheduleEntryFilterState> filterStates = [];

  FilterViewModel(this._scheduleEntryRepository, this._scheduleFilterRepository,
      this._scheduleSource) {
    loadFilterStates();
  }

  void loadFilterStates() async {
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

  void applyFilter() async {
    var allFilteredNames = filterStates
        .where((element) => !element.isDisplayed)
        .map((e) => e.entryName)
        .toList();

    await _scheduleFilterRepository.saveAllHiddenNames(allFilteredNames);

    KiwiContainer().resolve<ScheduleProvider>().invalidateScheduleCache();
    _scheduleSource.fireScheduleSourceChanged();
  }
}

class ScheduleEntryFilterState {
  bool isDisplayed;
  String entryName;

  ScheduleEntryFilterState(this.isDisplayed, this.entryName);
}
