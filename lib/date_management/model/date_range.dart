class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({
    required this.start,
    required this.end,
  });

  bool overlaps(DateTime rangeStart, DateTime rangeEnd) {
    return !rangeEnd.isBefore(start) && !rangeStart.isAfter(end);
  }

  static List<DateRange> merge(List<DateRange> ranges) {
    if (ranges.isEmpty) return [];

    var sorted = List<DateRange>.from(ranges)
      ..sort((a, b) => a.start.compareTo(b.start));

    var merged = <DateRange>[sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      var current = sorted[i];
      var last = merged.last;

      if (!current.start.isAfter(last.end)) {
        var end = current.end.isAfter(last.end) ? current.end : last.end;
        merged[merged.length - 1] = DateRange(start: last.start, end: end);
      } else {
        merged.add(current);
      }
    }

    return merged;
  }
}
