import 'dart:math' as math;

import '../models/calendar_models.dart';
import 'chinese_workday_calendar.dart';

class CalendarMonthlyRuleScheduler {
  const CalendarMonthlyRuleScheduler(this.workdayCalendar);

  final ChineseWorkdayCalendar workdayCalendar;

  DateTime occurrenceForMonth(CalendarMonthlyRule rule, int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final baseDay = math.min(rule.dayOfMonth, lastDay);
    if (rule.scheduleType == CalendarMonthlyScheduleType.fixedDay) {
      return DateTime(
        year,
        month,
        math.max(1, baseDay),
        rule.hour,
        rule.minute,
      );
    }

    final inMonth =
        rule.scheduleType == CalendarMonthlyScheduleType.nthWorkdayOfMonth;
    final targetOrdinal = switch (rule.scheduleType) {
      CalendarMonthlyScheduleType.firstWorkdayAfterDay => 1,
      CalendarMonthlyScheduleType.nthWorkdayOfMonth ||
      CalendarMonthlyScheduleType.nthWorkdayAfterDay => rule.workdayOrdinal,
      CalendarMonthlyScheduleType.fixedDay => 1,
    };
    // Day 0 starts at month start; a selected day starts strictly afterwards.
    var candidate = DateTime(year, month, inMonth ? 1 : baseDay + 1);
    DateTime? lastWorkday;
    var found = 0;
    for (var offset = 0; offset < 93; offset++) {
      if (inMonth && candidate.month != month) {
        if (lastWorkday != null) return _atReminderTime(lastWorkday, rule);
        break;
      }
      if (workdayCalendar.isWorkday(candidate)) {
        lastWorkday = candidate;
        found++;
        if (found == targetOrdinal) return _atReminderTime(candidate, rule);
      }
      candidate = DateTime(candidate.year, candidate.month, candidate.day + 1);
    }
    throw StateError('No workday found for $year-$month');
  }

  static DateTime _atReminderTime(DateTime date, CalendarMonthlyRule rule) =>
      DateTime(date.year, date.month, date.day, rule.hour, rule.minute);
}
