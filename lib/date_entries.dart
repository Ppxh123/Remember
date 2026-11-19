import 'lunar_date.dart';

enum DateEntryCalendar {
  gregorian('公历'),
  lunar('农历');

  const DateEntryCalendar(this.label);

  final String label;
}

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
  }) : lunarDate = null,
       targetDate = DateTime.utc(
         targetDate.year,
         targetDate.month,
         targetDate.day,
       );

  DateEntry.lunar({
    required this.title,
    required this.type,
    required LunarDate originalDate,
  }) : lunarDate = originalDate,
       targetDate = originalDate.gregorianDate {
    if (!type.repeats) throw ArgumentError.value(type, 'type');
  }

  final String title;
  final DateTime targetDate;
  final DateEntryType type;
  final LunarDate? lunarDate;

  DateEntryCalendar get calendar =>
      lunarDate == null ? DateEntryCalendar.gregorian : DateEntryCalendar.lunar;

  DateTime occurrenceFor(DateTime today) {
    if (!type.repeats || !targetDate.isBefore(today)) return targetDate;
    if (lunarDate case final lunar?) return lunar.dateAtOrAfter(today);

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
