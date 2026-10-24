import 'package:dualmate/schedule/model/schedule_source_type.dart';

/// An immutable source and its module choices. Exceptions invert the default,
/// so new modules remain included on the primary and excluded on additions.
class TimetableConfiguration {
  final String id;
  final String label;
  final ScheduleSourceType type;
  final String value;
  final bool includeAll;
  final Set<String> exceptions;

  TimetableConfiguration({
    required this.id,
    required this.label,
    required this.type,
    required this.value,
    this.includeAll = false,
    Set<String> exceptions = const {},
  }) : exceptions = Set.unmodifiable(exceptions);

  bool includes(String title) => includeAll != exceptions.contains(title);

  TimetableConfiguration withModule(String title, bool selected) {
    final next = Set<String>.from(exceptions);
    if (selected == includeAll) {
      next.remove(title);
    } else {
      next.add(title);
    }
    return TimetableConfiguration(
      id: id,
      label: label,
      type: type,
      value: value,
      includeAll: includeAll,
      exceptions: next,
    );
  }

  Map<String, Object> toRow(int position) => {
    'id': id,
    'label': label,
    'type': type.index,
    'value': value,
    'includeAll': includeAll ? 1 : 0,
    'position': position,
  };
}
