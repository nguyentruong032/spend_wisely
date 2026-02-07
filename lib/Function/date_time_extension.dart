extension DateTimeWeek on DateTime {
  int get weekOfYear {
    // Thursday of current week determines the ISO week year
    final thu = add(Duration(days: (4 - weekday + 7) % 7));
    final firstOfYear = DateTime(thu.year);

    // Find first Thursday of the year
    final firstThuOffset = (4 - firstOfYear.weekday + 7) % 7;
    final firstThu = firstOfYear.add(Duration(days: firstThuOffset));

    // Days between firstThu of year and our Thursday
    final daysDiff = thu.difference(firstThu).inDays;

    return (daysDiff ~/ 7) + 1;
  }
}
