class ScheduleUpdateRequestGate {
  final Duration minInterval;
  DateTime? _lastRequestAt;
  DateTime? _lastStart;
  DateTime? _lastEnd;

  ScheduleUpdateRequestGate({
    this.minInterval = const Duration(milliseconds: 300),
  });

  bool shouldAllow(DateTime start, DateTime end, DateTime now) {
    final isSameRange = _lastStart != null &&
        _lastEnd != null &&
        _lastStart == start &&
        _lastEnd == end;

    if (isSameRange &&
        _lastRequestAt != null &&
        now.difference(_lastRequestAt!) < minInterval) {
      return false;
    }

    _lastRequestAt = now;
    _lastStart = start;
    _lastEnd = end;
    return true;
  }
}
