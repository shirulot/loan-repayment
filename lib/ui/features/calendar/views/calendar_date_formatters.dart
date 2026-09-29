import 'package:lunar/lunar.dart';

String formatCalendarGregorianDate(DateTime date) =>
    '${date.year}年${date.month}月${date.day}日';

String formatCalendarTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String formatCalendarLunarDate(DateTime date) {
  try {
    final lunar = Solar.fromYmd(date.year, date.month, date.day).getLunar();
    return '农历${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
  } catch (_) {
    return '农历日期暂不可用';
  }
}

String formatCalendarDistanceFromToday(DateTime date, DateTime today) {
  final target = DateTime(date.year, date.month, date.day);
  final current = DateTime(today.year, today.month, today.day);
  final days = target.difference(current).inDays;
  if (days == 0) return '今天';
  if (days > 0) return '还有 $days 天';
  return '已过 ${days.abs()} 天';
}
