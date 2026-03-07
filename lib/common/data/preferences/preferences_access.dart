import 'package:shared_preferences/shared_preferences.dart';

class PreferencesAccess {
  final Future<SharedPreferences> Function() _instanceLoader;
  Future<SharedPreferences>? _instanceFuture;

  PreferencesAccess({Future<SharedPreferences> Function()? instanceLoader})
      : _instanceLoader = instanceLoader ?? SharedPreferences.getInstance;

  Future<SharedPreferences> _preferences() {
    final existing = _instanceFuture;
    if (existing != null) {
      return existing;
    }

    final created = _instanceLoader();
    _instanceFuture = created;
    return created;
  }

  Future<void> set<T>(String key, T value) async {
    final SharedPreferences prefs = await _preferences();

    switch (T) {
      case bool:
        await prefs.setBool(key, value as bool);
        return;
      case String:
        await prefs.setString(key, value as String);
        return;
      case double:
        await prefs.setDouble(key, value as double);
        return;
      case int:
        await prefs.setInt(key, value as int);
        return;
    }

    throw InvalidValueTypeException(T);
  }

  Future<T?> get<T>(String key) async {
    final SharedPreferences prefs = await _preferences();

    T? value;

    switch (T) {
      case bool:
        value = prefs.getBool(key) as T?;
        break;
      case String:
        value = prefs.getString(key) as T?;
        break;
      case double:
        value = prefs.getDouble(key) as T?;
        break;
      case int:
        value = prefs.getInt(key) as T?;
        break;
      default:
        throw InvalidValueTypeException(T);
    }

    return value;
  }
}

class InvalidValueTypeException implements Exception {
  final Type type;

  InvalidValueTypeException(this.type);
}
