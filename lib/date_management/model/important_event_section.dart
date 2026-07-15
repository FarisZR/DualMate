import 'package:dualmate/date_management/model/important_event.dart';

enum ImportantEventSectionKind { standalone, examWeek }

class ImportantEventSection {
  final ImportantEventSectionKind kind;
  final ImportantEvent? header;
  final List<ImportantEvent> events;

  const ImportantEventSection({
    required this.kind,
    required this.header,
    required this.events,
  }) : assert(
         (kind == ImportantEventSectionKind.standalone &&
                 header == null &&
                 events.length == 1) ||
             (kind == ImportantEventSectionKind.examWeek && header != null),
         'standalone sections contain exactly one event and no header; '
         'examWeek sections require a header',
       );
}
