import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/material.dart';

/// 日期网格独立横向翻页，纵向拖动仍交给外层日历滚动区域。
class CalendarMonthPager extends StatefulWidget {
  const CalendarMonthPager({
    super.key,
    required this.month,
    required this.onMonthChanged,
    required this.monthBuilder,
  });

  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;
  final Widget Function(BuildContext, DateTime) monthBuilder;

  @override
  State<CalendarMonthPager> createState() => _CalendarMonthPagerState();
}

class _CalendarMonthPagerState extends State<CalendarMonthPager> {
  // 页码按自然月连续排列，12 月和次年 1 月也是相邻两页。
  int _pageOf(DateTime month) => month.year * 12 + month.month - 1;

  late final _controller = PageController(
    initialPage: _pageOf(widget.month),
    keepPage: false,
  );

  @override
  void didUpdateWidget(covariant CalendarMonthPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // “今天”、月份箭头、通知跳转都能从分页器外部指定月份。
    if (DateUtils.isSameMonth(oldWidget.month, widget.month)) return;
    final page = _pageOf(widget.month);
    if (_controller.hasClients && _controller.page != page.toDouble()) {
      _controller.jumpToPage(page);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    final metrics = notification.metrics;
    if (notification.depth != 0 || metrics is! PageMetrics) return false;
    final position = metrics.page;
    if (position == null) return false;
    final page = position.round();
    // 吸附中途可能再次被按住，仅在整页到位后更新选中日期和明细。
    if ((position - page).abs() > precisionErrorTolerance) return false;
    if (page != _pageOf(widget.month)) {
      widget.onMonthChanged(DateTime(0, page + 1));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return NotificationListener<ScrollEndNotification>(
      onNotification: _onScrollEnd,
      child: PageView.builder(
        controller: _controller,
        scrollBehavior: behavior.copyWith(
          dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
          scrollbars: false,
        ),
        itemBuilder: (context, page) =>
            widget.monthBuilder(context, DateTime(0, page + 1)),
      ),
    );
  }
}
