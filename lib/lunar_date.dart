import 'package:lunar/lunar.dart' as calendar;

final class LunarDate {
  LunarDate({
    required this.year,
    required this.month,
    required this.day,
    this.isLeapMonth = false,
  }) {
    RangeError.checkValueInInterval(year, firstYear, lastYear, 'year');
    final dayCount = daysInMonth(year, month, isLeapMonth: isLeapMonth);
    if (dayCount == null || day < 1 || day > dayCount) {
      throw ArgumentError('Invalid lunar month or day');
    }
  }

  static LunarDate? fromGregorian(DateTime date) {
    if (date.year < firstYear || date.year > lastYear + 1) return null;
    final lunar = _lunarOn(date);
    final year = lunar.getYear();
    if (year < firstYear || year > lastYear) return null;

    return LunarDate(
      year: year,
      month: lunar.getMonth().abs(),
      day: lunar.getDay(),
      isLeapMonth: lunar.getMonth() < 0,
    );
  }

  static const firstYear = 1901;
  static const lastYear = 2100;

  final int year;
  final int month;
  final int day;
  final bool isLeapMonth;

  int get signedMonth => isLeapMonth ? -month : month;

  String get label =>
      '$year年${isLeapMonth ? '闰' : ''}${calendar.LunarUtil.MONTH[month]}月'
      '${calendar.LunarUtil.DAY[day]}';

  late final DateTime gregorianDate = _gregorian(year, signedMonth, day);

  static int? daysInMonth(int year, int month, {required bool isLeapMonth}) {
    if (month < 1 || month > 12) return null;
    return calendar.LunarMonth.fromYm(
      year,
      isLeapMonth ? -month : month,
    )?.getDayCount();
  }

  DateTime dateAtOrAfter(DateTime today) {
    final currentYear = _lunarOn(today).getYear();
    final occurrence = _occurrenceIn(currentYear);
    return occurrence.isBefore(today)
        ? _occurrenceIn(currentYear + 1)
        : occurrence;
  }

  DateTime _occurrenceIn(int lunarYear) {
    final requested = calendar.LunarMonth.fromYm(lunarYear, signedMonth);
    final actual = requested ?? calendar.LunarMonth.fromYm(lunarYear, month)!;
    return _gregorian(
      lunarYear,
      actual.getMonth(),
      day.clamp(1, actual.getDayCount()),
    );
  }

  static calendar.Lunar _lunarOn(DateTime date) =>
      calendar.Solar.fromYmd(date.year, date.month, date.day).getLunar();

  static int yearOn(DateTime date) => _lunarOn(date).getYear();

  static DateTime _gregorian(int year, int month, int day) {
    final solar = calendar.Lunar.fromYmd(year, month, day).getSolar();
    return DateTime.utc(solar.getYear(), solar.getMonth(), solar.getDay());
  }
}
