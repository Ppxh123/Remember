final class DateEntry {
  DateEntry({required this.title, required DateTime targetDate})
    : targetDate = DateTime.utc(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );

  final String title;
  final DateTime targetDate;
}

abstract interface class DateEntries {
  Future<List<DateEntry>> read();
  Future<void> add(DateEntry entry);
}
