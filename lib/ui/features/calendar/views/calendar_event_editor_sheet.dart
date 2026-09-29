import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/models/calendar_models.dart';

enum _NoteRecurrenceMode { once, fixedDay, nthWorkday, nthWorkdayAfterDay }

class CalendarEventEditorSheet extends StatefulWidget {
  const CalendarEventEditorSheet({
    super.key,
    required this.initialDate,
    required this.defaultReminderTime,
    this.node,
    this.monthlyRule,
  });

  final DateTime initialDate;
  final TimeOfDay defaultReminderTime;
  final CalendarNode? node;
  final CalendarMonthlyRule? monthlyRule;

  @override
  State<CalendarEventEditorSheet> createState() =>
      _CalendarEventEditorSheetState();
}

class _CalendarEventEditorSheetState extends State<CalendarEventEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late DateTime _date;
  late TimeOfDay _time;
  late bool _notificationsEnabled;
  late _NoteRecurrenceMode _recurrenceMode;
  late int _dayOfMonth;
  late int _workdayOrdinal;

  CalendarNode? get _node => widget.node;
  CalendarMonthlyRule? get _monthlyRule => widget.monthlyRule;
  bool get _isLinkedPrepayment =>
      _node?.source == CalendarNodeSource.prepayment;

  @override
  void initState() {
    super.initState();
    final node = _node;
    final rule = _monthlyRule;
    _titleController = TextEditingController(
      text: node?.title ?? rule?.title ?? '',
    );
    _noteController = TextEditingController(
      text: node?.note ?? rule?.note ?? '',
    );
    _date = node?.dateTime ?? widget.initialDate;
    _time = node != null
        ? TimeOfDay.fromDateTime(node.dateTime)
        : rule != null
        ? TimeOfDay(hour: rule.hour, minute: rule.minute)
        : widget.defaultReminderTime;
    _notificationsEnabled =
        node?.notificationsEnabled ?? rule?.notificationsEnabled ?? true;
    _recurrenceMode = switch (rule?.scheduleType) {
      CalendarMonthlyScheduleType.fixedDay => _NoteRecurrenceMode.fixedDay,
      CalendarMonthlyScheduleType.nthWorkdayOfMonth =>
        _NoteRecurrenceMode.nthWorkday,
      CalendarMonthlyScheduleType.nthWorkdayAfterDay ||
      CalendarMonthlyScheduleType.firstWorkdayAfterDay =>
        _NoteRecurrenceMode.nthWorkdayAfterDay,
      null => _NoteRecurrenceMode.once,
    };
    _dayOfMonth = rule?.dayOfMonth ?? _date.day;
    _workdayOrdinal = rule?.workdayOrdinal ?? 1;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    if (!_isLinkedPrepayment && !_formKey.currentState!.validate()) return;
    final node = _node;
    final rule = _monthlyRule;
    if (!_isLinkedPrepayment && _recurrenceMode != _NoteRecurrenceMode.once) {
      Navigator.of(context).pop(
        CalendarMonthlyRule(
          id:
              rule?.id ??
              'calendar-rule-${DateTime.now().microsecondsSinceEpoch}',
          type: CalendarMonthlyRuleType.note,
          createdAt: rule?.createdAt ?? DateTime.now(),
          scheduleType: switch (_recurrenceMode) {
            _NoteRecurrenceMode.fixedDay =>
              CalendarMonthlyScheduleType.fixedDay,
            _NoteRecurrenceMode.nthWorkday =>
              CalendarMonthlyScheduleType.nthWorkdayOfMonth,
            _NoteRecurrenceMode.nthWorkdayAfterDay =>
              CalendarMonthlyScheduleType.nthWorkdayAfterDay,
            _NoteRecurrenceMode.once => CalendarMonthlyScheduleType.fixedDay,
          },
          dayOfMonth: _dayOfMonth,
          workdayOrdinal: _workdayOrdinal,
          hour: _time.hour,
          minute: _time.minute,
          notificationsEnabled: _notificationsEnabled,
          customTitle: _titleController.text.trim(),
          note: _noteController.text.trim(),
        ),
      );
      return;
    }
    final dateTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    if (node == null) {
      Navigator.of(context).pop(
        CalendarNode(
          id: 'calendar-${DateTime.now().microsecondsSinceEpoch}',
          title: _titleController.text.trim(),
          dateTime: dateTime,
          note: _noteController.text.trim(),
          notificationsEnabled: _notificationsEnabled,
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      node.copyWith(
        title: _isLinkedPrepayment ? null : _titleController.text.trim(),
        note: _isLinkedPrepayment ? null : _noteController.text.trim(),
        dateTime: dateTime,
        notificationsEnabled: _notificationsEnabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEditing = _node != null || _monthlyRule != null;
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isLinkedPrepayment
                  ? '提前还款提醒'
                  : isEditing
                  ? '编辑备注'
                  : '新建备注',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (!_isLinkedPrepayment) ...[
              TextFormField(
                controller: _titleController,
                autofocus: !isEditing,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: '标题',
                  counterText: '',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入标题' : null,
              ),
              const SizedBox(height: 12),
            ] else ...[
              InputDecorator(
                decoration: const InputDecoration(labelText: '标题'),
                child: Text(_node!.title),
              ),
              const SizedBox(height: 12),
            ],
            if (!_isLinkedPrepayment) ...[
              DropdownButtonFormField<_NoteRecurrenceMode>(
                initialValue: _recurrenceMode,
                decoration: const InputDecoration(labelText: '重复'),
                items: const [
                  DropdownMenuItem(
                    value: _NoteRecurrenceMode.once,
                    child: Text('仅此一次'),
                  ),
                  DropdownMenuItem(
                    value: _NoteRecurrenceMode.fixedDay,
                    child: Text('每月固定日期'),
                  ),
                  DropdownMenuItem(
                    value: _NoteRecurrenceMode.nthWorkday,
                    child: Text('每月第几个工作日'),
                  ),
                  DropdownMenuItem(
                    value: _NoteRecurrenceMode.nthWorkdayAfterDay,
                    child: Text('每月某日后第几个工作日'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _recurrenceMode = value);
                },
              ),
              const SizedBox(height: 12),
            ],
            if (_recurrenceMode == _NoteRecurrenceMode.fixedDay ||
                _recurrenceMode == _NoteRecurrenceMode.nthWorkdayAfterDay) ...[
              DropdownButtonFormField<int>(
                key: const ValueKey('note-month-day'),
                initialValue: _dayOfMonth.clamp(1, 31),
                decoration: InputDecoration(
                  labelText: _recurrenceMode == _NoteRecurrenceMode.fixedDay
                      ? '每月日期'
                      : '从每月几日之后开始',
                ),
                items: [
                  for (var day = 1; day <= 31; day++)
                    DropdownMenuItem(value: day, child: Text('每月$day日')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _dayOfMonth = value);
                },
              ),
              const SizedBox(height: 12),
            ],
            if (_recurrenceMode == _NoteRecurrenceMode.nthWorkday ||
                _recurrenceMode == _NoteRecurrenceMode.nthWorkdayAfterDay) ...[
              DropdownButtonFormField<int>(
                key: const ValueKey('note-workday-ordinal'),
                initialValue: _workdayOrdinal,
                decoration: const InputDecoration(labelText: '第几个工作日'),
                items: [
                  for (var ordinal = 1; ordinal <= 22; ordinal++)
                    DropdownMenuItem(
                      value: ordinal,
                      child: Text('第$ordinal个工作日'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _workdayOrdinal = value);
                },
              ),
              const SizedBox(height: 8),
              Text(
                _recurrenceMode == _NoteRecurrenceMode.nthWorkday
                    ? '当月工作日不足时，落在最后一个工作日'
                    : '从所选日期次日算起，可能顺延到下个月',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                if (_recurrenceMode == _NoteRecurrenceMode.once)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLinkedPrepayment ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        '${_date.year}年${_date.month}月${_date.day}日',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (_recurrenceMode == _NoteRecurrenceMode.once)
                  const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(_time.format(context)),
                ),
              ],
            ),
            if (!_isLinkedPrepayment) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                maxLength: 240,
                decoration: const InputDecoration(labelText: '备注'),
              ),
            ] else if (_node!.amount != null) ...[
              const SizedBox(height: 12),
              Text(
                '提前还款金额 ¥${_node!.amount!.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('到时提醒'),
              value: _notificationsEnabled,
              onChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }
}
