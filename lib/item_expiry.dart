enum ShelfLifeUnit {
  days('天'),
  months('月'),
  years('年');

  const ShelfLifeUnit(this.label);
  final String label;
}

final class ShelfLife {
  ShelfLife({
    required DateTime producedOn,
    required this.amount,
    required this.unit,
  }) : producedOn = DateTime.utc(
         producedOn.year,
         producedOn.month,
         producedOn.day,
       );

  final DateTime producedOn;
  final int amount;
  final ShelfLifeUnit unit;

  DateTime get expiryDate {
    final start = producedOn;
    final last = DateTime.utc(9999, 12, 31);
    if (amount < 1) throw ArgumentError.value(amount, 'amount');
    if (unit == ShelfLifeUnit.days) {
      if (amount > last.difference(start).inDays) {
        throw RangeError.value(amount);
      }
      return start.add(Duration(days: amount));
    }

    final multiplier = unit == ShelfLifeUnit.years ? 12 : 1;
    final availableMonths =
        (last.year - start.year) * 12 + last.month - start.month;
    if (amount > availableMonths ~/ multiplier) throw RangeError.value(amount);
    final month = DateTime.utc(start.year, start.month + amount * multiplier);
    final lastDay = DateTime.utc(month.year, month.month + 1, 0).day;
    return DateTime.utc(month.year, month.month, start.day.clamp(1, lastDay));
  }
}

final class ItemExpiry {
  ItemExpiry.direct(DateTime date)
    : date = DateTime.utc(date.year, date.month, date.day),
      shelfLife = null;

  ItemExpiry.calculated(ShelfLife shelfLife)
    : date = shelfLife.expiryDate,
      shelfLife = shelfLife;

  final DateTime date;
  final ShelfLife? shelfLife;

  String statusOn(DateTime today) {
    final days = date.difference(today).inDays;
    return switch (days) {
      > 0 => '还有 $days 天到期',
      0 => '今日到期',
      _ => '已过期 ${days.abs()} 天',
    };
  }
}
