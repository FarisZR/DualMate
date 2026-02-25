import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/filter_view_model.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
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
      _FakeScheduleSourceProvider(),
      _FakeScheduleProvider(),
    );

    await viewModel.initialize();

    expect(
        viewModel.filterStates.map((e) => e.entryName), ['Class A', 'Class B']);
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
      _FakeScheduleSourceProvider(),
      _FakeScheduleProvider(),
    );

    await viewModel.initialize();

    expect(viewModel.filterStates.map((e) => e.entryName), ['Class A']);
    expect(entryRepository.queryAllNamesCallCount, 1);
  });
}

class _FakeScheduleEntryRepository implements ScheduleEntryRepository {
  List<String> names;
  int queryAllNamesCallCount = 0;

  _FakeScheduleEntryRepository(this.names);

  @override
  Future<List<String>> queryAllNamesOfScheduleEntries() async {
    queryAllNamesCallCount += 1;
    return List<String>.from(names);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
        'Unexpected ScheduleEntryRepository call: $invocation');
  }
}

class _FakeScheduleFilterRepository implements ScheduleFilterRepository {
  final List<String> hiddenNames;

  _FakeScheduleFilterRepository(this.hiddenNames);

  @override
  Future<List<String>> queryAllHiddenNames() async {
    return List<String>.from(hiddenNames);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
        'Unexpected ScheduleFilterRepository call: $invocation');
  }
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
        'Unexpected ScheduleSourceProvider call: $invocation');
  }
}

class _FakeScheduleProvider implements ScheduleProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}
