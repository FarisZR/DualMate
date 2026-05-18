import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/filter_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FilterViewModel.resetCachedStateForTesting();
  });

  tearDown(() {
    FilterViewModel.resetCachedStateForTesting();
  });

  test('preload does not keep empty states as final cache', () async {
    final entryRepository = _FakeScheduleEntryRepository([]);
    final filterRepository = _FakeScheduleFilterRepository([]);

    await FilterViewModel.preloadStates(entryRepository, filterRepository);

    entryRepository.names = ['Class B', 'Class A'];
    final viewModel = FilterViewModel(
      entryRepository,
      filterRepository,
    );

    await viewModel.initialize();

    expect(
      viewModel.filterStates.map((e) => e.entryName),
      ['Class A', 'Class B'],
    );
    expect(entryRepository.queryAllNamesCallCount, 2);
  });

  test('preload keeps non-empty states for fast open', () async {
    final entryRepository = _FakeScheduleEntryRepository(['Class A']);
    final filterRepository = _FakeScheduleFilterRepository([]);

    await FilterViewModel.preloadStates(entryRepository, filterRepository);

    entryRepository.names = ['Class B'];
    final viewModel = FilterViewModel(
      entryRepository,
      filterRepository,
    );

    await viewModel.initialize();

    expect(viewModel.filterStates.map((e) => e.entryName), ['Class A']);
    expect(entryRepository.queryAllNamesCallCount, 1);
  });

  test('loadFilterStates handles empty results without preload', () async {
    final entryRepository = _FakeScheduleEntryRepository([]);
    final filterRepository = _FakeScheduleFilterRepository([]);

    final viewModel = FilterViewModel(
      entryRepository,
      filterRepository,
    );

    await viewModel.initialize();

    expect(viewModel.filterStates, isEmpty);
    expect(entryRepository.queryAllNamesCallCount, 1);
  });

  test('applyFilter returns false when hidden names stay unchanged', () async {
    final entryRepository = _FakeScheduleEntryRepository(['Class A']);
    final filterRepository = _FakeScheduleFilterRepository([]);

    final viewModel = FilterViewModel(
      entryRepository,
      filterRepository,
    );

    await viewModel.initialize();

    final didChange = await viewModel.applyFilter();

    expect(didChange, isFalse);
    expect(filterRepository.savedHiddenNames, isEmpty);
  });

  test('applyFilter persists hidden names and updates cache', () async {
    final entryRepository = _FakeScheduleEntryRepository(['Class A']);
    final filterRepository = _FakeScheduleFilterRepository([]);

    final viewModel = FilterViewModel(
      entryRepository,
      filterRepository,
    );

    await viewModel.initialize();
    viewModel.filterStates.first.isDisplayed = false;

    final didChange = await viewModel.applyFilter();

    expect(didChange, isTrue);
    expect(filterRepository.savedHiddenNames, [
      ['Class A'],
    ]);

    final cachedViewModel = FilterViewModel(
      entryRepository,
      filterRepository,
    );
    await cachedViewModel.initialize();
    expect(cachedViewModel.filterStates.first.isDisplayed, isFalse);
  });
}

class _FakeScheduleEntryRepository implements ScheduleEntryRepository {
  List<String> names;
  int queryAllNamesCallCount = 0;

  _FakeScheduleEntryRepository(this.names);

  @override
  Future<List<String>> queryAllNamesOfScheduleEntries() async {
    queryAllNamesCallCount += 1;
    final sortedNames = List<String>.from(names)..sort();
    return sortedNames;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleEntryRepository call: $invocation',
    );
  }
}

class _FakeScheduleFilterRepository implements ScheduleFilterRepository {
  final List<String> hiddenNames;
  final List<List<String>> savedHiddenNames = <List<String>>[];

  _FakeScheduleFilterRepository(this.hiddenNames);

  @override
  Future<List<String>> queryAllHiddenNames() async {
    return List<String>.from(hiddenNames);
  }

  @override
  Future<void> saveAllHiddenNames(List<String> hiddenNames) async {
    savedHiddenNames.add(List<String>.from(hiddenNames));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleFilterRepository call: $invocation',
    );
  }
}
