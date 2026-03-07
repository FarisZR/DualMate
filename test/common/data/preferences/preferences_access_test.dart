import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('reuses a single shared preferences instance across operations',
      () async {
    var loaderCalls = 0;
    final access = PreferencesAccess(
      instanceLoader: () async {
        loaderCalls += 1;
        return SharedPreferences.getInstance();
      },
    );

    await access.set<String>('name', 'dualmate');
    await access.set<int>('count', 2);

    expect(await access.get<String>('name'), 'dualmate');
    expect(await access.get<int>('count'), 2);
    expect(loaderCalls, 1);
  });

  test('concurrent reads still initialize shared preferences once', () async {
    var loaderCalls = 0;
    final access = PreferencesAccess(
      instanceLoader: () async {
        loaderCalls += 1;
        return SharedPreferences.getInstance();
      },
    );

    await access.set<int>('value', 42);
    await Future.wait([
      access.get<int>('value'),
      access.get<int>('value'),
      access.get<int>('value'),
    ]);

    expect(loaderCalls, 1);
  });
}
