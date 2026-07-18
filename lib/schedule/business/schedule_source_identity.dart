import 'package:dualmate/schedule/model/schedule_source_type.dart';

abstract final class ScheduleSourceIdentity {
  static const Set<String> _transientRaplaParameters = {
    'day',
    'month',
    'year',
    'next',
    'prev',
    'goto',
  };

  static String create(ScheduleSourceType type, String configuredValue) {
    final normalized = switch (type) {
      ScheduleSourceType.Rapla => normalizeRaplaUrl(configuredValue),
      ScheduleSourceType.Dualis => configuredValue.trim().toLowerCase(),
      ScheduleSourceType.Ical ||
      ScheduleSourceType.Mannheim => configuredValue.trim(),
      ScheduleSourceType.None => '',
    };
    return '${type.name.toLowerCase()}:${_stableHash(normalized)}';
  }

  static String normalizeRaplaUrl(String value) {
    var raw = value.trim();
    if (raw.isEmpty) return raw;
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }

    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;

    final entries = <MapEntry<String, String>>[];
    final keys = uri.queryParametersAll.keys.toList()..sort();
    for (final key in keys) {
      if (_transientRaplaParameters.contains(key.toLowerCase())) continue;
      final values = List<String>.from(uri.queryParametersAll[key] ?? const [])
        ..sort();
      for (final item in values) {
        entries.add(MapEntry(key, item));
      }
    }

    return uri
        .replace(
          scheme: uri.scheme.toLowerCase(),
          host: uri.host.toLowerCase(),
          fragment: '',
          queryParameters: entries.isEmpty
              ? const <String, String>{}
              : Map<String, String>.fromEntries(entries),
        )
        .toString();
  }

  static String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final byte in value.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
