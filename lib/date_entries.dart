enum DateEntryType {
  oneTime('一次性日期'),
  birthday('生日'),
  anniversary('纪念日');

  const DateEntryType(this.label);

  final String label;

  bool get repeats => this != oneTime;
}

final class DateEntry {
  DateEntry({
    required this.title,
    required DateTime targetDate,
    this.type = DateEntryType.oneTime,
  }) : targetDate = DateTime.utc(
         targetDate.year,
         targetDate.month,
         targetDate.day,
       );

  final String title;
  final DateTime targetDate;
  final DateEntryType type;

  DateTime occurrenceFor(DateTime today) {
    if (!type.repeats || !targetDate.isBefore(today)) return targetDate;

    final thisYear = _occurrenceIn(today.year);
    return thisYear.isBefore(today) ? _occurrenceIn(today.year + 1) : thisYear;
  }

  DateTime _occurrenceIn(int year) {
    final month = targetDate.month;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    return DateTime.utc(year, month, targetDate.day.clamp(1, lastDay));
  }
}

abstract interface class DateEntries {
  Future<List<DateEntry>> read();
  Future<void> add(DateEntry entry);
}
