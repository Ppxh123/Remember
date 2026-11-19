import 'package:flutter_test/flutter_test.dart';
import 'package:remember/date_entries.dart';
import 'package:remember/lunar_date.dart';

void main() {
  // Independent fixtures from the Hong Kong Observatory conversion tables:
  // https://www.hko.gov.hk/en/gts/time/conversion.htm
  test('闰月生日在下一年回退到普通月，到再有闰月时还原', () {
    final entry = DateEntry.lunar(
      title: '生日',
      type: DateEntryType.birthday,
      originalDate: LunarDate(year: 2023, month: 2, day: 10, isLeapMonth: true),
    );

    expect(
      entry.occurrenceFor(DateTime.utc(2023, 3, 31)),
      DateTime.utc(2023, 3, 31),
    );
    expect(
      entry.occurrenceFor(DateTime.utc(2023, 4, 1)),
      DateTime.utc(2024, 3, 19),
    );
    expect(
      entry.occurrenceFor(DateTime.utc(2042, 3, 2)),
      DateTime.utc(2042, 3, 31),
    );
    expect(entry.lunarDate?.label, '2023年闰二月初十');
  });

  test('普通二月生日在同年遇到闰二月时仍只计算一次', () {
    final entry = DateEntry.lunar(
      title: '生日',
      type: DateEntryType.birthday,
      originalDate: LunarDate(year: 2023, month: 2, day: 10),
    );

    expect(
      entry.occurrenceFor(DateTime.utc(2023, 3, 1)),
      DateTime.utc(2023, 3, 1),
    );
    expect(
      entry.occurrenceFor(DateTime.utc(2023, 3, 2)),
      DateTime.utc(2024, 3, 19),
    );
  });

  test('农历三十遇小月取二十九，后续大月仍取三十', () {
    final entry = DateEntry.lunar(
      title: '纪念日',
      type: DateEntryType.anniversary,
      originalDate: LunarDate(year: 2023, month: 4, day: 30),
    );

    expect(entry.targetDate, DateTime.utc(2023, 6, 17));
    expect(
      entry.occurrenceFor(DateTime.utc(2024, 6, 5)),
      DateTime.utc(2024, 6, 5),
    );
    expect(
      entry.occurrenceFor(DateTime.utc(2042, 6, 16)),
      DateTime.utc(2042, 6, 17),
    );
    expect(entry.lunarDate?.day, 30);
  });

  test('公历元旦后仍可命中上一农历年的腊月', () {
    final entry = DateEntry.lunar(
      title: '纪念日',
      type: DateEntryType.anniversary,
      originalDate: LunarDate(year: 2022, month: 12, day: 10),
    );

    expect(entry.targetDate, DateTime.utc(2023, 1, 1));
    expect(
      entry.occurrenceFor(DateTime.utc(2024, 1, 10)),
      DateTime.utc(2024, 1, 20),
    );
  });

  test('原始农历日期限定在 1901–2100 年及实际月日', () {
    expect(LunarDate(year: 1901, month: 1, day: 1).year, 1901);
    expect(LunarDate(year: 2100, month: 1, day: 1).year, 2100);
    expect(() => LunarDate(year: 1900, month: 1, day: 1), throwsRangeError);
    expect(() => LunarDate(year: 2101, month: 1, day: 1), throwsRangeError);
    expect(
      () => LunarDate(year: 2024, month: 2, day: 10, isLeapMonth: true),
      throwsArgumentError,
    );
    expect(() => LunarDate(year: 2024, month: 4, day: 30), throwsArgumentError);
  });
}
