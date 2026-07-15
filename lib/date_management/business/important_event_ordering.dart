import 'dart:convert';

import 'package:dualmate/date_management/model/important_event.dart';

final RegExp _importantEventTitleSeparators = RegExp(r'[\s\.-]');

String normalizeImportantEventTitle(String title) {
  return title.toLowerCase().replaceAll(_importantEventTitleSeparators, '');
}

List<ImportantEvent> sortImportantEvents(Iterable<ImportantEvent> events) {
  final keyed =
      events
          .map(
            (event) => _ImportantEventSortKey(
              event,
              normalizeImportantEventTitle(event.title),
            ),
          )
          .toList(growable: false)
        ..sort(_compareImportantEventKeys);
  return keyed.map((key) => key.event).toList(growable: false);
}

String importantEventStableIdentity(ImportantEvent event) {
  return jsonEncode(<Object>[
    event.start.toIso8601String(),
    event.end.toIso8601String(),
    event.title,
    event.professor,
    event.type.index,
  ]);
}

class _ImportantEventSortKey {
  final ImportantEvent event;
  final String normalizedTitle;

  const _ImportantEventSortKey(this.event, this.normalizedTitle);
}

int _compareImportantEventKeys(
  _ImportantEventSortKey first,
  _ImportantEventSortKey second,
) {
  var comparison = first.event.start.compareTo(second.event.start);
  if (comparison != 0) return comparison;
  comparison = first.event.end.compareTo(second.event.end);
  if (comparison != 0) return comparison;
  comparison = first.normalizedTitle.compareTo(second.normalizedTitle);
  if (comparison != 0) return comparison;
  comparison = first.event.professor.compareTo(second.event.professor);
  if (comparison != 0) return comparison;
  return first.event.type.index.compareTo(second.event.type.index);
}
