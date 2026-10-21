import 'package:flutter/material.dart';

import '../view_models/calendar_view_model.dart';
import 'calendar_date_formatters.dart';

/// The selected day's details share the same callbacks in portrait and F.
class CalendarDayPanel extends StatelessWidget {
  const CalendarDayPanel({
    super.key,
    required this.selectedDate,
    required this.occurrences,
    required this.isWorkday,
    required this.holidayName,
    required this.onAddNote,
    required this.onMarkAllRead,
    required this.onOpenOccurrence,
    required this.deleteAction,
    this.outlinedOccurrences = false,
  });

  final DateTime selectedDate;
  final List<CalendarDayOccurrence> occurrences;
  final bool isWorkday;
  final String? holidayName;
  final VoidCallback onAddNote;
  final VoidCallback onMarkAllRead;
  final ValueChanged<CalendarDayOccurrence> onOpenOccurrence;
  final VoidCallback? Function(CalendarDayOccurrence) deleteAction;
  final bool outlinedOccurrences;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasUnread = occurrences.any((item) => item.isUnread);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatCalendarGregorianDate(selectedDate),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatCalendarLunarDate(selectedDate)}  ·  ${formatCalendarDistanceFromToday(selectedDate, DateTime.now())}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isWorkday ? '工作日' : '休息日'}${holidayName == null ? '' : ' · $holidayName'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: '添加当天备注',
              onPressed: onAddNote,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                occurrences.isEmpty ? '没有日历节点' : '${occurrences.length} 个节点',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            if (hasUnread)
              TextButton.icon(
                onPressed: onMarkAllRead,
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          )
        else
          for (var index = 0; index < occurrences.length; index++) ...[
            if (outlinedOccurrences)
              Card.outlined(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _CalendarOccurrenceTile(
                    occurrence: occurrences[index],
                    onTap: () => onOpenOccurrence(occurrences[index]),
                    onDelete: deleteAction(occurrences[index]),
                  ),
                ),
              )
            else
              _CalendarOccurrenceTile(
                occurrence: occurrences[index],
                onTap: () => onOpenOccurrence(occurrences[index]),
                onDelete: deleteAction(occurrences[index]),
              ),
            if (!outlinedOccurrences && index < occurrences.length - 1)
              const Divider(height: 1, indent: 48),
          ],
      ],
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
