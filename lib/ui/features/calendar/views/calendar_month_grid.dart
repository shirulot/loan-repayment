import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'calendar_layout_style.dart';

class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.today,
    required this.hasEvents,
    required this.hasUnread,
    required this.isWorkday,
    required this.holidayName,
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
    this.monthHeadingKey,
    this.showHeading = true,
    this.fitMonthRows = false,
    this.cellHeight = 56,
  });

  final DateTime month;
  final DateTime selectedDate;
  final DateTime today;
  final bool Function(DateTime) hasEvents;
  final bool Function(DateTime) hasUnread;
  final bool Function(DateTime) isWorkday;
  final String? Function(DateTime) holidayName;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final Key? monthHeadingKey;
  final bool showHeading;
  final bool fitMonthRows;
  final double cellHeight;

  /// Wide calendars avoid an unnecessary sixth week while retaining every
  /// date in months that genuinely span six weeks.
  static int weekCount(DateTime month) {
    final offset = DateTime(month.year, month.month).weekday - DateTime.monday;
    final days = DateTime(month.year, month.month + 1, 0).day;
    return ((offset + days) / 7).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final firstDay = DateTime(month.year, month.month, 1);
    final startOffset = firstDay.weekday - DateTime.monday;
    // Enlarged accessibility text needs taller dates; the surrounding pane
    // remains scrollable instead of clipping holiday labels or event dots.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final effectiveCellHeight = math.max(
      cellHeight,
      CalendarLayoutStyle.minimumCellHeight * textScale,
    );
    return Column(
      children: [
        if (showHeading)
          Row(
            children: [
              Expanded(
                child: Text(
                  '${month.year}年${month.month}月',
                  key: monthHeadingKey,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: '今天',
                onPressed: onToday,
                icon: const Icon(Icons.today_outlined),
              ),
              IconButton(
                tooltip: '上个月',
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: '下个月',
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        if (showHeading) const SizedBox(height: 4),
        const Row(
          children: [
            _WeekdayLabel('一'),
            _WeekdayLabel('二'),
            _WeekdayLabel('三'),
            _WeekdayLabel('四'),
            _WeekdayLabel('五'),
            _WeekdayLabel('六', isWeekend: true),
            _WeekdayLabel('日', isWeekend: true),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.maxWidth / 7;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: fitMonthRows ? weekCount(month) * 7 : 42,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: cellWidth / effectiveCellHeight,
              ),
              itemBuilder: (context, index) {
                final day = DateTime(
                  month.year,
                  month.month,
                  index - startOffset + 1,
                );
                final isCurrentMonth = day.month == month.month;
                final isSelected = _isSameDay(day, selectedDate);
                final isToday = _isSameDay(day, today);
                final hasDayEvents = hasEvents(day);
                final hasUnreadEvents = hasUnread(day);
                final workday = isWorkday(day);
                return _CalendarDayCell(
                  date: day,
                  isWorkday: workday,
                  holidayName: holidayName(day),
                  isCurrentMonth: isCurrentMonth,
                  isSelected: isSelected,
                  isToday: isToday,
                  hasEvents: hasDayEvents,
                  hasUnread: hasUnreadEvents,
                  onTap: () => onDateSelected(day),
                  selectedColor: colors.primary,
                  selectedTextColor: colors.onPrimary,
                  todayBorderColor: colors.primary,
                  mutedTextColor: colors.onSurfaceVariant.withValues(
                    alpha: 0.46,
                  ),
                  holidayTextColor: colors.onSurfaceVariant,
                  eventColor: colors.tertiary,
                  unreadColor: colors.error,
                  restColor: colors.error,
                  adjustedWorkColor: colors.tertiary,
                );
              },
            );
          },
        ),
      ],
    );
  }

  static bool _isSameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label, {this.isWeekend = false});

  final String label;
  final bool isWeekend;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Center(
      child: SizedBox(
        height: 28,
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isWeekend
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    ),
  );
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isWorkday,
    required this.holidayName,
    required this.isCurrentMonth,
    required this.isSelected,
    required this.isToday,
    required this.hasEvents,
    required this.hasUnread,
    required this.onTap,
    required this.selectedColor,
    required this.selectedTextColor,
    required this.todayBorderColor,
    required this.mutedTextColor,
    required this.holidayTextColor,
    required this.eventColor,
    required this.unreadColor,
    required this.restColor,
    required this.adjustedWorkColor,
  });

  final DateTime date;
  final bool isWorkday;
  final String? holidayName;
  final bool isCurrentMonth;
  final bool isSelected;
  final bool isToday;
  final bool hasEvents;
  final bool hasUnread;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color selectedTextColor;
  final Color todayBorderColor;
  final Color mutedTextColor;
  final Color holidayTextColor;
  final Color eventColor;
  final Color unreadColor;
  final Color restColor;
  final Color adjustedWorkColor;

  @override
  Widget build(BuildContext context) {
    final isWeekend = date.weekday >= DateTime.saturday;
    final status = !isWorkday
        ? '休'
        : isWeekend
        ? '班'
        : null;
    final festival = holidayName?.replaceFirst(RegExp(r'(前|后)补班$'), '');
    final dayColor = !isCurrentMonth
        ? mutedTextColor
        : isSelected
        ? selectedTextColor
        : !isWorkday
        ? restColor
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${date.year}年${date.month}月${date.day}日，${isWorkday ? '工作日' : '休息日'}${holidayName == null ? '' : '，$holidayName'}',
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            border: isToday && !isSelected
                ? Border.all(color: todayBorderColor)
                : null,
            color: isSelected ? selectedColor : null,
          ),
          child: Stack(
            children: [
              if (status != null)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 9,
                      color: isSelected
                          ? selectedTextColor
                          : status == '班'
                          ? adjustedWorkColor
                          : restColor,
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${date.day}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: dayColor,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(9) * 1.45,
                      child: festival == null
                          ? null
                          : Text(
                              festival,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                color: isSelected
                                    ? selectedTextColor
                                    : !isCurrentMonth
                                    ? mutedTextColor
                                    : !isWorkday
                                    ? restColor
                                    : holidayTextColor,
                              ),
                            ),
                    ),
                    SizedBox(
                      height: 6,
                      child: hasEvents
                          ? Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: hasUnread
                                    ? unreadColor
                                    : isSelected
                                    ? selectedTextColor
                                    : eventColor,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
