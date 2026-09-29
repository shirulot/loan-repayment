import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/models/calendar_models.dart';
import '../view_models/calendar_view_model.dart';

class CalendarMonthlyRulesSheet extends StatelessWidget {
  const CalendarMonthlyRulesSheet({super.key, required this.viewModel});

  final CalendarViewModel viewModel;

  Future<void> _editRule(
    BuildContext context, {
    required CalendarMonthlyRuleType type,
    CalendarMonthlyRule? rule,
  }) async {
    final result = await showModalBottomSheet<CalendarMonthlyRule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => CalendarMonthlyRuleEditorSheet(
        type: type,
        rule: rule,
        defaultReminderTime: viewModel.defaultReminderTime,
      ),
    );
    if (result != null) viewModel.saveMonthlyRule(result);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CalendarMonthlyRule rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除${rule.title}节点？'),
        content: const Text('之后的每月提醒也会一并移除。'),
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 +
            math.max(
              MediaQuery.viewInsetsOf(context).bottom,
              MediaQuery.viewPaddingOf(context).bottom,
            ),
      ),
      child: AnimatedBuilder(
        animation: viewModel,
        builder: (context, _) {
          final rules = viewModel.data.monthlyRules
              .where((rule) => rule.type != CalendarMonthlyRuleType.note)
              .toList();
          final existingTypes = rules.map((rule) => rule.type).toSet();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('每月节点', style: Theme.of(context).textTheme.titleLarge),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('默认提醒时间'),
                subtitle: const Text('新建节点时使用'),
                trailing: Text(
                  TimeOfDay(
                    hour: viewModel.defaultReminderTime.hour,
                    minute: viewModel.defaultReminderTime.minute,
                  ).format(context),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                onTap: () => _editDefaultTime(context),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  viewModel.isHolidayDataRefreshing
                      ? '调休日历更新中'
                      : _holidayDataStatus(viewModel.holidayDataUpdatedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (rules.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    '还没有设置每月扣款节点',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final rule in rules)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_repeat_outlined),
                    title: Text(rule.title),
                    subtitle: Text(_summary(rule)),
                    onTap: () =>
                        _editRule(context, type: rule.type, rule: rule),
                    trailing: IconButton(
                      tooltip: '删除${rule.title}',
                      onPressed: () => _confirmDelete(context, rule),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
              if (!existingTypes.contains(
                CalendarMonthlyRuleType.commercialPayment,
              )) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _editRule(
                    context,
                    type: CalendarMonthlyRuleType.commercialPayment,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('设置商贷扣款日'),
                ),
              ],
              if (!existingTypes.contains(
                CalendarMonthlyRuleType.providentFirstWorkday,
              )) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _editRule(
                    context,
                    type: CalendarMonthlyRuleType.providentFirstWorkday,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('设置公积金扣款日'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _summary(CalendarMonthlyRule rule) {
    final schedule = switch (rule.scheduleType) {
      CalendarMonthlyScheduleType.fixedDay => '每月${rule.dayOfMonth}日',
      CalendarMonthlyScheduleType.firstWorkdayAfterDay =>
        rule.dayOfMonth == 0 ? '每月第一个工作日' : '每月${rule.dayOfMonth}日后第一个工作日',
      CalendarMonthlyScheduleType.nthWorkdayOfMonth =>
        '每月第${rule.workdayOrdinal}个工作日',
      CalendarMonthlyScheduleType.nthWorkdayAfterDay =>
        '每月${rule.dayOfMonth}日后第${rule.workdayOrdinal}个工作日',
    };
    final time = TimeOfDay(
      hour: rule.hour,
      minute: rule.minute,
    ).formatFrom24Hour();
    return '$schedule · $time';
  }

  String _holidayDataStatus(DateTime? updatedAt) {
    if (updatedAt == null) return '使用应用内置调休数据';
    return '调休数据更新于 ${updatedAt.year}年${updatedAt.month}月${updatedAt.day}日';
  }

  Future<void> _editDefaultTime(BuildContext context) async {
    final current = viewModel.defaultReminderTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    viewModel.setDefaultReminderTime(
      TimeOfDayValue(picked.hour, picked.minute),
    );
  }
}

class CalendarMonthlyRuleEditorSheet extends StatefulWidget {
  const CalendarMonthlyRuleEditorSheet({
    super.key,
    required this.type,
    required this.defaultReminderTime,
    this.rule,
  });

  final CalendarMonthlyRuleType type;
  final TimeOfDayValue defaultReminderTime;
  final CalendarMonthlyRule? rule;

  @override
  State<CalendarMonthlyRuleEditorSheet> createState() =>
      _CalendarMonthlyRuleEditorSheetState();
}

class _CalendarMonthlyRuleEditorSheetState
    extends State<CalendarMonthlyRuleEditorSheet> {
  late CalendarMonthlyScheduleType _scheduleType;
  late int _dayOfMonth;
  late TimeOfDay _time;
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _scheduleType =
        rule?.scheduleType ??
        (widget.type == CalendarMonthlyRuleType.providentFirstWorkday
            ? CalendarMonthlyScheduleType.firstWorkdayAfterDay
            : CalendarMonthlyScheduleType.fixedDay);
    _dayOfMonth =
        rule?.dayOfMonth ??
        (widget.type == CalendarMonthlyRuleType.providentFirstWorkday ? 0 : 1);
    _time = rule == null
        ? TimeOfDay(
            hour: widget.defaultReminderTime.hour,
            minute: widget.defaultReminderTime.minute,
          )
        : TimeOfDay(hour: rule.hour, minute: rule.minute);
    _notificationsEnabled = rule?.notificationsEnabled ?? true;
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (time != null) setState(() => _time = time);
  }

  void _save() {
    final existing = widget.rule;
    Navigator.of(context).pop(
      CalendarMonthlyRule(
        id:
            existing?.id ??
            'calendar-rule-${DateTime.now().microsecondsSinceEpoch}',
        type: widget.type,
        createdAt: existing?.createdAt ?? DateTime.now(),
        scheduleType: _scheduleType,
        dayOfMonth: _dayOfMonth,
        hour: _time.hour,
        minute: _time.minute,
        notificationsEnabled: _notificationsEnabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFixed = _scheduleType == CalendarMonthlyScheduleType.fixedDay;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 +
            math.max(
              MediaQuery.viewInsetsOf(context).bottom,
              MediaQuery.viewPaddingOf(context).bottom,
            ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.rule == null ? '设置' : '编辑'}$_title',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SegmentedButton<CalendarMonthlyScheduleType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: CalendarMonthlyScheduleType.fixedDay,
                label: Text('固定日期'),
              ),
              ButtonSegment(
                value: CalendarMonthlyScheduleType.firstWorkdayAfterDay,
                label: Text('顺延工作日'),
              ),
            ],
            selected: {_scheduleType},
            onSelectionChanged: (selection) => setState(() {
              _scheduleType = selection.single;
              if (_scheduleType == CalendarMonthlyScheduleType.fixedDay &&
                  _dayOfMonth == 0) {
                _dayOfMonth = 1;
              }
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey(_scheduleType),
            initialValue: _dayOfMonth,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: isFixed ? '每月扣款日' : '从哪一日之后找工作日',
              helperText: isFixed ? '当月没有所选日期时，按月末计算' : '按法定调休判断，必要时顺延到下月',
            ),
            items: [
              if (!isFixed)
                const DropdownMenuItem(value: 0, child: Text('月初第一个工作日')),
              for (var day = 1; day <= 31; day++)
                DropdownMenuItem(
                  value: day,
                  child: Text(isFixed ? '每月$day日' : '每月$day日后'),
                ),
            ],
            onChanged: (day) {
              if (day != null) setState(() => _dayOfMonth = day);
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule_outlined),
            label: Text('提醒时间  ${_time.format(context)}'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('到时提醒'),
            value: _notificationsEnabled,
            onChanged: (value) => setState(() => _notificationsEnabled = value),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
        ],
      ),
    );
  }

  String get _title => switch (widget.type) {
    CalendarMonthlyRuleType.commercialPayment => '商贷扣款日',
    CalendarMonthlyRuleType.providentFirstWorkday => '公积金扣款日',
    CalendarMonthlyRuleType.note => '备注',
  };
}

extension on TimeOfDay {
  String formatFrom24Hour() {
    final hourText = hour.toString().padLeft(2, '0');
    final minuteText = minute.toString().padLeft(2, '0');
    return '$hourText:$minuteText';
  }
}
