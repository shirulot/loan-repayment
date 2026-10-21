import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/models/calendar_models.dart';
import '../view_models/calendar_view_model.dart';
import 'calendar_day_panel.dart';
import 'calendar_layout_style.dart';
import 'calendar_event_editor_sheet.dart';
import 'calendar_month_grid.dart';
import 'calendar_monthly_rules_sheet.dart';
import 'calendar_occurrence_detail_sheet.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.viewModel,
    this.initialSelectedDate,
  });

  final CalendarViewModel viewModel;
  final DateTime? initialSelectedDate;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final ScrollController _monthScrollController = ScrollController();
  final ScrollController _dayScrollController = ScrollController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewportKey = GlobalKey();
  final GlobalKey _monthHeadingKey = GlobalKey();
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  bool _monthHeadingOffscreen = false;

  CalendarViewModel get viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _selectInitialDate(widget.initialSelectedDate ?? DateTime.now());
    _scrollController.addListener(_updateAppBarTitle);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _monthScrollController.dispose();
    _dayScrollController.dispose();
    super.dispose();
  }

  void _updateAppBarTitle() {
    final heading = _monthHeadingKey.currentContext?.findRenderObject();
    final viewport = _scrollViewportKey.currentContext?.findRenderObject();
    if (heading is! RenderBox || viewport is! RenderBox) return;
    // Switch only after the entire in-content month heading has left view.
    final headingBottom = heading
        .localToGlobal(Offset(0, heading.size.height))
        .dy;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final offscreen = headingBottom <= viewportTop;
    if (offscreen != _monthHeadingOffscreen) {
      setState(() => _monthHeadingOffscreen = offscreen);
    }
  }

  @override
  void didUpdateWidget(covariant CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelectedDate != widget.initialSelectedDate &&
        widget.initialSelectedDate != null) {
      setState(() => _selectInitialDate(widget.initialSelectedDate!));
    }
  }

  void _selectInitialDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    _visibleMonth = DateTime(date.year, date.month, 1);
  }

  void _selectDate(DateTime date) {
    _resetWideScroll();
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
      _visibleMonth = DateTime(date.year, date.month, 1);
    });
  }

  void _changeMonth(int amount) {
    _resetWideScroll();
    setState(() {
      final month = DateTime(_visibleMonth.year, _visibleMonth.month + amount);
      final day = math
          .min(_selectedDate.day, DateTime(month.year, month.month + 1, 0).day)
          .toInt();
      _visibleMonth = DateTime(month.year, month.month, 1);
      _selectedDate = DateTime(month.year, month.month, day);
    });
  }

  void _resetWideScroll() {
    // A newly selected day/month starts at its heading; resizing alone keeps
    // the independent pane positions and selected date unchanged.
    if (_monthScrollController.hasClients) _monthScrollController.jumpTo(0);
    if (_dayScrollController.hasClients) _dayScrollController.jumpTo(0);
  }

  Future<void> _openEditor({
    CalendarNode? node,
    CalendarMonthlyRule? monthlyRule,
  }) async {
    final defaultTime = viewModel.defaultReminderTime;
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => CalendarEventEditorSheet(
        initialDate: _selectedDate,
        defaultReminderTime: TimeOfDay(
          hour: defaultTime.hour,
          minute: defaultTime.minute,
        ),
        node: node,
        monthlyRule: monthlyRule,
      ),
    );
    if (result == null) return;
    if (result is CalendarMonthlyRule) {
      if (node != null) viewModel.deleteNode(node.id);
      viewModel.saveMonthlyRule(result);
    } else if (result is CalendarNode) {
      if (monthlyRule != null) viewModel.deleteMonthlyRule(monthlyRule.id);
      if (node == null) {
        viewModel.addNote(result);
      } else {
        viewModel.updateNode(result);
      }
    }
  }

  Future<void> _openOccurrence(CalendarDayOccurrence occurrence) async {
    viewModel.markRead(occurrence.key);
    final node = occurrence.node;
    if (node?.source == CalendarNodeSource.prepayment) {
      final editReminder = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => CalendarOccurrenceDetailSheet(
          occurrence: occurrence,
          onEditReminder: () => Navigator.of(sheetContext).pop(true),
        ),
      );
      if (editReminder == true && mounted) await _openEditor(node: node);
      return;
    }
    if (node != null) {
      await _openEditor(node: node);
      return;
    }
    final rule = occurrence.rule;
    if (rule?.type == CalendarMonthlyRuleType.note) {
      await _openEditor(monthlyRule: rule);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => CalendarOccurrenceDetailSheet(occurrence: occurrence),
    );
  }

  Future<void> _confirmDelete(CalendarNode node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这个日历节点？'),
        content: Text('“${node.title}”将从日历和提醒中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) viewModel.deleteNode(node.id);
  }

  Future<void> _confirmDeleteMonthlyNote(CalendarMonthlyRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除每月备注？'),
        content: Text('“${rule.title}”的所有月份节点和提醒都将移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) viewModel.deleteMonthlyRule(rule.id);
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => CalendarMonthlyRulesSheet(viewModel: viewModel),
    );
  }

  Widget _dayPanel({bool wide = false}) => CalendarDayPanel(
    selectedDate: _selectedDate,
    occurrences: viewModel.occurrencesOn(_selectedDate),
    isWorkday: viewModel.isWorkdayOn(_selectedDate),
    holidayName: viewModel.holidayNameOn(_selectedDate),
    outlinedOccurrences: wide,
    onAddNote: () => _openEditor(),
    onMarkAllRead: viewModel.markAllRead,
    onOpenOccurrence: _openOccurrence,
    deleteAction: (occurrence) => switch (occurrence) {
      CalendarDayOccurrence(node: final node?)
          when node.source == CalendarNodeSource.note =>
        () => _confirmDelete(node),
      CalendarDayOccurrence(rule: final rule?)
          when rule.type == CalendarMonthlyRuleType.note =>
        () => _confirmDeleteMonthlyNote(rule),
      _ => null,
    },
  );

  CalendarMonthGrid _monthGrid({bool wide = false, double cellHeight = 56}) =>
      CalendarMonthGrid(
        monthHeadingKey: wide ? null : _monthHeadingKey,
        month: _visibleMonth,
        selectedDate: _selectedDate,
        today: DateTime.now(),
        hasEvents: viewModel.hasOccurrencesOn,
        hasUnread: viewModel.hasUnreadOn,
        isWorkday: viewModel.isWorkdayOn,
        holidayName: viewModel.holidayNameOn,
        onDateSelected: _selectDate,
        onPreviousMonth: () => _changeMonth(-1),
        onNextMonth: () => _changeMonth(1),
        onToday: () => _selectDate(DateTime.now()),
        showHeading: !wide,
        fitMonthRows: wide,
        cellHeight: cellHeight,
      );

  Widget _splitBody() => LayoutBuilder(
    builder: (context, constraints) {
      final padding = constraints.maxHeight < 400
          ? CalendarLayoutStyle.compactPadding
          : CalendarLayoutStyle.desktopPadding;
      final rows = CalendarMonthGrid.weekCount(_visibleMonth);
      // Keep touch targets usable: a short six-week month scrolls instead of
      // shrinking dates below 44 points. Taller windows spread out the grid.
      final cellHeight =
          ((constraints.maxHeight -
                      padding * 4 -
                      CalendarLayoutStyle.weekdayHeadingHeight) /
                  rows)
              .clamp(
                CalendarLayoutStyle.minimumCellHeight,
                CalendarLayoutStyle.maximumCellHeight,
              )
              .toDouble();
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: CalendarLayoutStyle.maxWidth,
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Card.outlined(
                    margin: EdgeInsets.zero,
                    child: Scrollbar(
                      controller: _monthScrollController,
                      child: SingleChildScrollView(
                        controller: _monthScrollController,
                        padding: EdgeInsets.all(padding),
                        child: _monthGrid(wide: true, cellHeight: cellHeight),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: CalendarLayoutStyle.gap),
                Expanded(
                  flex: 2,
                  child: Card.outlined(
                    margin: EdgeInsets.zero,
                    child: Scrollbar(
                      controller: _dayScrollController,
                      child: SingleChildScrollView(
                        controller: _dayScrollController,
                        padding: EdgeInsets.all(padding),
                        child: _dayPanel(wide: true),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= CalendarLayoutStyle.splitMinWidth;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            wide || _monthHeadingOffscreen
                ? '${wide ? '日历 · ' : ''}${_visibleMonth.year}年${_visibleMonth.month}月'
                : '日历',
          ),
          actions: [
            if (wide) ...[
              IconButton(
                tooltip: '上个月',
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: '下个月',
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: '今天',
                onPressed: () => _selectDate(DateTime.now()),
                icon: const Icon(Icons.today_outlined),
              ),
            ],
            TextButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.event_repeat_outlined),
              label: const Text('扣款日'),
            ),
            IconButton(
              tooltip: '添加备注节点',
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: viewModel,
            builder: (context, _) {
              if (wide) return _splitBody();
              return LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth < 420
                      ? 12.0
                      : 20.0;
                  return SingleChildScrollView(
                    key: _scrollViewportKey,
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      8,
                      horizontalPadding,
                      28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _monthGrid(),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            _dayPanel(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
    },
  );
}
