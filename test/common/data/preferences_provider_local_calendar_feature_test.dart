import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'calendar sync preference is forced off when feature is disabled',
    () async {
      final preferencesAccess = _FakePreferencesAccess({
        'isCalendarSyncEnabled': true,
        'SelectedCalendarId': 'calendar-1',
      });
      final provider = PreferencesProvider(
        preferencesAccess,
        _FakeSecureStorageAccess(),
      );

      expect(await provider.isCalendarSyncEnabled(), isFalse);
      expect(await provider.getSelectedCalendar(), isNull);

      await provider.setIsCalendarSyncEnabled(true);
      await provider.setSelectedCalendar(null);

      expect(
        await preferencesAccess.get<bool>('isCalendarSyncEnabled'),
        isFalse,
      );
      expect(await preferencesAccess.get<String>('SelectedCalendarId'), '');
    },
  );
}

class _FakePreferencesAccess extends PreferencesAccess {
  final Map<String, Object?> _values;

  _FakePreferencesAccess(this._values);

  @override
  Future<T?> get<T>(String key) async => _values[key] as T?;

  @override
  Future<void> set<T>(String key, T value) async {
    _values[key] = value;
  }
}

class _FakeSecureStorageAccess extends SecureStorageAccess {
  @override
  Future<String?> get(String key) async => null;

  @override
  Future<void> set(String key, String value) async {}
}
