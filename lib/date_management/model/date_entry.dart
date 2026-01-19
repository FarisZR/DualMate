class DateEntry {
  final String description;
  final String year;
  final String comment;
  final String databaseName;
  final DateTime start;
  final DateTime end;
  final String room;

  DateEntry({
    required this.description,
    required this.year,
    required this.comment,
    required this.databaseName,
    required this.start,
    required this.end,
    required this.room,
  });
}
