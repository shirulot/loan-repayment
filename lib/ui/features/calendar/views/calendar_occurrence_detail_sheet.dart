import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../view_models/calendar_view_model.dart';
import 'calendar_date_formatters.dart';

class CalendarOccurrenceDetailSheet extends StatelessWidget {
  const CalendarOccurrenceDetailSheet({
    super.key,
    required this.occurrence,
    this.onEditReminder,
  });

  final CalendarDayOccurrence occurrence;
  final VoidCallback? onEditReminder;

  @override
  Widget build(BuildContext context) {
    final details = occurrence.paymentDetails;
    final prepayment = occurrence.prepaymentDetails;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        28 +
            math.max(
              MediaQuery.viewInsetsOf(context).bottom,
              MediaQuery.viewPaddingOf(context).bottom,
            ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(occurrence.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '${formatCalendarGregorianDate(occurrence.dateTime)}  ${formatCalendarTime(occurrence.dateTime)}',
          ),
          if (details != null) ...[
            const SizedBox(height: 16),
            _DetailRow('月供总额', _money(details.payment), emphasized: true),
            const Divider(height: 24),
            _DetailRow('本金', _money(details.principal)),
            _DetailRow('利息', _money(details.interest)),
            _DetailRow(
              '年利率',
              '${(details.annualRate * 100).toStringAsFixed(3)}%',
            ),
            _DetailRow('还款方式', details.repaymentMethod.label),
            _DetailRow('期初余额', _money(details.openingBalance)),
            _DetailRow('月供后余额', _money(details.closingBalance)),
            _DetailRow('剩余期数', '${details.remainingTerms}期'),
          ] else if (prepayment != null) ...[
            const SizedBox(height: 16),
            _DetailRow('本次提前还贷', _money(prepayment.amount), emphasized: true),
            const Divider(height: 24),
            _DetailRow('预期金额', _money(prepayment.expectedAmount)),
            if (prepayment.actualPrepayment != null)
              _DetailRow('实际金额', _money(prepayment.actualPrepayment!)),
            _DetailRow('当日提前利息', _money(prepayment.interestDueNow)),
            _DetailRow('交易后商贷余额', _money(prepayment.commercialClosing)),
            _DetailRow('交易后公积金余额', _money(prepayment.providentClosing)),
          ] else if (occurrence.rule != null) ...[
            const SizedBox(height: 16),
            const Text('当前还款计划暂无该月金额明细'),
          ] else if (occurrence.amount != null) ...[
            const SizedBox(height: 16),
            _DetailRow('金额', _money(occurrence.amount!)),
          ],
          if (occurrence.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(occurrence.note),
          ],
          if (onEditReminder != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onEditReminder,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('编辑提醒'),
            ),
          ],
        ],
      ),
    );
  }

  static String _money(double amount) => '¥${amount.toStringAsFixed(2)}';
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.emphasized = false});

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          Text(
            value,
            style: emphasized
                ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
                : textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
