import 'dart:convert';

import 'package:dualmate/date_management/model/important_event.dart';

final RegExp _importantEventTitleSeparators = RegExp(r'[\s\.-]');

String normalizeImportantEventTitle(String title) {
  return title.toLowerCase().replaceAll(_importantEventTitleSeparators, '');
}

List<ImportantEvent> sortImportantEvents(Iterable<ImportantEvent> events) {
  final keyed =
      events.map(ImportantEventOrderingKey.new).toList(growable: false)..sort();
  return keyed.map((key) => key.event).toList(growable: false);
}

String importantEventStableIdentity(ImportantEvent event) {
  return _importantEventStableIdentity(event);
}

String _importantEventStableIdentity(ImportantEvent event) =>
    jsonEncode(<Object>[
      event.start.toIso8601String(),
      event.end.toIso8601String(),
      event.title,
      event.professor,
      event.type.index,
      event.details,
      event.room,
    ]);

class ImportantEventOrderingKey
    implements Comparable<ImportantEventOrderingKey> {
  final ImportantEvent event;
  final String normalizedTitle;
  final String stableIdentity;

  ImportantEventOrderingKey(this.event)
    : normalizedTitle = normalizeImportantEventTitle(event.title),
      stableIdentity = _importantEventStableIdentity(event);

  @override
  int compareTo(ImportantEventOrderingKey other) {
    var comparison = event.start.compareTo(other.event.start);
    if (comparison != 0) return comparison;
    comparison = event.end.compareTo(other.event.end);
    if (comparison != 0) return comparison;
    comparison = normalizedTitle.compareTo(other.normalizedTitle);
    if (comparison != 0) return comparison;
    comparison = event.professor.compareTo(other.event.professor);
    if (comparison != 0) return comparison;
    comparison = event.type.index.compareTo(other.event.type.index);
    if (comparison != 0) return comparison;
    return stableIdentity.compareTo(other.stableIdentity);
  }
}
