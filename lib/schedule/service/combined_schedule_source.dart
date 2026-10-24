import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

/// Query atomically: a failed source never looks like deleted lessons.
class CombinedScheduleSource implements ScheduleSource {
  final Map<String, ScheduleSource> sources;
  CombinedScheduleSource(Map<String, ScheduleSource> sources)
    : sources = Map.unmodifiable(sources);
  @override
  bool canQuery() =>
      sources.isNotEmpty && sources.values.every((s) => s.canQuery());
  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? token,
  ]) async {
    if (!canQuery())
      throw ScheduleQueryFailedException(
        StateError('Invalid timetable configuration'),
      );
    token?.throwIfCancelled();
    final children = {for (final id in sources.keys) id: CancellationToken()};
    token?.setCancellationCallback(() {
      for (final child in children.values) child.cancel();
    });
    try {
      final results = await Future.wait(
        sources.entries.map((source) async {
          final result = await source.value.querySchedule(
            from,
            to,
            children[source.key],
          );
          return ScheduleQueryResult(
            result.schedule.copyWith(
              entries: result.schedule.entries
                  .map((e) => e.copyWith(sourceIdentity: source.key))
                  .toList(),
            ),
            result.errors,
          );
        }),
      );
      final schedule = Schedule();
      final seen = <Record>{};
      for (final result in results) {
        schedule.urls.addAll(result.schedule.urls);
        for (final entry in result.schedule.entries) {
          // Match equalsWithIdIgnored without a quadratic scan of every
          // previously merged lesson on the UI isolate.
          final key = (
            entry.sourceIdentity,
            entry.start,
            entry.end,
            entry.title,
            entry.details,
            entry.professor,
            entry.room,
            entry.type,
          );
          if (seen.add(key)) schedule.addEntry(entry);
        }
      }
      return ScheduleQueryResult(
        schedule,
        results.expand((r) => r.errors).toList(),
      );
    } finally {
      token?.setCancellationCallback(null);
    }
  }
}
