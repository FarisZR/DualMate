import 'package:dualmate/date_management/model/important_event.dart';

class ImportantEventSection {
  final ImportantEvent? header;
  final List<ImportantEvent> events;

  ImportantEventSection({
    required this.header,
    required this.events,
  });
}
