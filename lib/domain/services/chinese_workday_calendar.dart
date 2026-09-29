import 'package:lunar/lunar.dart';

class ChineseWorkdayCalendar {
  ChineseWorkdayCalendar({
    Map<int, bool> overrides = const <int, bool>{},
    Map<int, String> holidayNames = const <int, String>{},
  }) : _overrides = Map<int, bool>.of(overrides),
       _holidayNames = Map<int, String>.of(holidayNames);

  final Map<int, bool> _overrides;
  final Map<int, String> _holidayNames;

  void updateData(Map<int, bool> overrides, Map<int, String> holidayNames) {
    _overrides
      ..clear()
      ..addAll(overrides);
    _holidayNames
      ..clear()
      ..addAll(holidayNames);
  }

  String? holidayName(DateTime date) {
    final downloaded = _holidayNames[_dateKey(date)];
    if (downloaded != null) return downloaded;
    final holiday = HolidayUtil.getHolidayByYmd(
      date.year,
      date.month,
      date.day,
    );
    if (holiday != null) return holiday.getName();
    try {
      final solar = Solar.fromYmd(date.year, date.month, date.day);
      final solarFestivals = solar.getFestivals();
      if (solarFestivals.isNotEmpty) return solarFestivals.first;
      final lunarFestivals = solar.getLunar().getFestivals();
      if (lunarFestivals.isNotEmpty) return lunarFestivals.first;
    } catch (_) {
      // Dates outside the bundled lunar range still retain work/rest status.
    }
    return null;
  }

  /// Prefers validated network data, then uses the bundled holiday calendar.
  bool isWorkday(DateTime date) {
    final override = _overrides[_dateKey(date)];
    if (override != null) return override;
    final holiday = HolidayUtil.getHolidayByYmd(
      date.year,
      date.month,
      date.day,
    );
    if (holiday != null) return holiday.isWork();
    return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
  }

  DateTime firstWorkday(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    var day = 1;
    while (day <= lastDay && !isWorkday(DateTime(year, month, day))) {
      day++;
    }
    if (day > lastDay) {
      throw StateError('No workday in $year-$month');
    }
    return DateTime(year, month, day);
  }

  static int _dateKey(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;
}
