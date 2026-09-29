import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/models/calendar_models.dart';
import '../view_models/calendar_view_model.dart';
import 'calendar_date_formatters.dart';
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
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
      _visibleMonth = DateTime(date.year, date.month, 1);
    });
  }

  void _changeMonth(int amount) {
    setState(() {
      final month = DateTime(_visibleMonth.year, _visibleMonth.month + amount);
      final day = math
          .min(_selectedDate.day, DateTime(month.year, month.month + 1, 0).day)
          .toInt();
      _visibleMonth = DateTime(month.year, month.month, 1);
      _selectedDate = DateTime(month.year, month.month, day);
    });
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _monthHeadingOffscreen
              ? '${_visibleMonth.year}年${_visibleMonth.month}月'
              : '日历',
        ),
        actions: [
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
            final occurrences = viewModel.occurrencesOn(_selectedDate);
            final hasUnread = occurrences.any((item) => item.isUnread);
            final holidayName = viewModel.holidayNameOn(_selectedDate);
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
                          CalendarMonthGrid(
                            monthHeadingKey: _monthHeadingKey,
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
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formatCalendarGregorianDate(
                                        _selectedDate,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${formatCalendarLunarDate(_selectedDate)}  ·  ${formatCalendarDistanceFromToday(_selectedDate, DateTime.now())}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${viewModel.isWorkdayOn(_selectedDate) ? '工作日' : '休息日'}${holidayName == null ? '' : ' · $holidayName'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: '添加当天备注',
                                onPressed: () => _openEditor(),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  occurrences.isEmpty
                                      ? '没有日历节点'
                                      : '${occurrences.length} 个节点',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              if (hasUnread)
                                TextButton.icon(
                                  onPressed: viewModel.markAllRead,
                                  icon: const Icon(Icons.done_all, size: 18),
                                  label: const Text('全部已读'),
                                ),
                            ],
                          ),
                          if (occurrences.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                '点击右侧加号添加备注',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            )
                          else
                            for (
                              var index = 0;
                              index < occurrences.length;
                              index++
                            ) ...[
                              _CalendarOccurrenceTile(
                                occurrence: occurrences[index],
                                onTap: () =>
                                    _openOccurrence(occurrences[index]),
                                onDelete: switch (occurrences[index]) {
                                  CalendarDayOccurrence(node: final node?)
                                      when node.source ==
                                          CalendarNodeSource.note =>
                                    () => _confirmDelete(node),
                                  CalendarDayOccurrence(rule: final rule?)
                                      when rule.type ==
                                          CalendarMonthlyRuleType.note =>
                                    () => _confirmDeleteMonthlyNote(rule),
                                  _ => null,
                                },
                              ),
                              if (index < occurrences.length - 1)
                                const Divider(height: 1, indent: 48),
                            ],
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
  }
}

class _CalendarOccurrenceTile extends StatelessWidget {
  const _CalendarOccurrenceTile({
    required this.occurrence,
    required this.onTap,
    this.onDelete,
  });

  final CalendarDayOccurrence occurrence;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final amount = occurrence.amount;
    final note = occurrence.note.trim();
    final subtitle = <String>[
      if (amount != null) '月供 ¥${amount.toStringAsFixed(2)}',
      if (note.isNotEmpty) note,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Badge(
        isLabelVisible: occurrence.isUnread,
        smallSize: 8,
        backgroundColor: colors.error,
        child: Icon(
          occurrence.rule == null
              ? Icons.event_note_outlined
              : Icons.event_repeat_outlined,
          color: occurrence.isUnread ? colors.error : colors.primary,
        ),
      ),
      title: Text(occurrence.title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCalendarTime(occurrence.dateTime),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (onDelete != null)
            IconButton(
              tooltip: '删除节点',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
