class ScheduleFreshnessGate {
  final Duration staleAfter;
  DateTime? _lastFetchedAt;
  DateTime? _lastStart;
  DateTime? _lastEnd;

  ScheduleFreshnessGate({
    this.staleAfter = const Duration(minutes: 30),
  });

  bool isStale(DateTime start, DateTime end, DateTime now) {
    if (_lastFetchedAt == null || _lastStart == null || _lastEnd == null) {
      return true;
    }

    if (_lastStart != start || _lastEnd != end) {
      return true;
    }

    return now.difference(_lastFetchedAt!).abs() > staleAfter;
  }

  void markFetched(DateTime start, DateTime end, DateTime now) {
    _lastStart = start;
    _lastEnd = end;
    _lastFetchedAt = now;
  }

  void reset() {
    _lastStart = null;
    _lastEnd = null;
    _lastFetchedAt = null;
  }
}
