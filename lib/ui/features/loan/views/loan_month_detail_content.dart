import 'package:flutter/material.dart';

import '../../../../core/extensions/string_extensions.dart';
import '../../../../domain/models/loan_models.dart';
import 'loan_plan_calendar_formatters.dart';
import 'loan_plan_formatters.dart';
import 'loan_plan_display_row.dart';

/// Renders the complete data card list for one repayment month.
class LoanMonthDetailContent extends StatelessWidget {
  const LoanMonthDetailContent({
    super.key,
    required this.row,
    required this.displayed,
    required this.amountsMasked,
    required this.nextMonthBasePaymentReduction,
  });

  final LoanPlanRow row;
  final List<LoanPlanDisplayRow> displayed;
  final bool amountsMasked;
  final double? nextMonthBasePaymentReduction;

  String _money(double value) =>
      formatLoanMoneyProtected(value, masked: amountsMasked);

  String _optionalMoney(double? value) {
    if (value == null) return amountsMasked ? '****' : '—';
    return _money(value);
  }

  String _date(String? value) {
    if (amountsMasked) return '****';
    return value == null || value.isBlank ? '—' : value;
  }

  LoanDetailItem _moneyItem(String label, double value) =>
      LoanDetailItem(label, _money(value));

  LoanDetailItem _optionalMoneyItem(String label, double? value) =>
      LoanDetailItem(label, _optionalMoney(value));

  /// 历史利率按当期账单计息口径展示，不读当前设置的利率。
  LoanDetailItem _annualRateItem(double rate, {required bool inferred}) =>
      LoanDetailItem(
        inferred ? '年利率（反推）' : '年利率',
        amountsMasked ? '****' : '${(rate * 100).toStringAsFixed(3)}%',
      );

  @override
  Widget build(BuildContext context) {
    final commercialBreakdownEstimated =
        row.commercialPaymentEvidence != LoanPaymentEvidence.statement;
    final prepaymentDates = row.prepaymentDates.isEmpty
        ? '无'
        : row.prepaymentDates.join('、');
    final repaymentStatus = row.isArchived
        ? '历史账单'
        : row.actualPrepayment != null
        ? '已录入实际提前还款'
        : row.prepaymentDetails.isNotEmpty
        ? '有预约或预测提前还款'
        : '本月无提前还款';

    return SingleChildScrollView(
      key: PageStorageKey<String>('month-detail-scroll-${row.month}'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoanDetailCard(
            title: '月份与还款状态',
            icon: Icons.calendar_month_outlined,
            items: [
              LoanDetailItem('公历月份', row.month),
              LoanDetailItem('农历月份', formatLoanLunarMonth(row.month)),
              LoanDetailItem('剩余期数', '${row.remainingTerms} 期'),
              LoanDetailItem('还款状态', repaymentStatus),
              LoanDetailItem('计划还贷日期', _date(row.plannedPrepaymentDate)),
              LoanDetailItem('生效还贷日期', _date(row.effectivePrepaymentDate)),
              LoanDetailItem(
                '实际生效日期',
                amountsMasked ? '****' : prepaymentDates,
              ),
            ],
          ),
          LoanDetailCard(
            title: '商贷月供构成',
            icon: Icons.account_balance_outlined,
            items: [
              _moneyItem('商贷期初本金', row.commercialOpening),
              if (row.commercialAnnualRate case final rate?)
                _annualRateItem(
                  rate,
                  inferred: row.commercialAnnualRateInferred,
                ),
              _moneyItem(
                commercialBreakdownEstimated ? '商贷月供本金（反推）' : '商贷月供本金',
                row.commercialPrincipal,
              ),
              _moneyItem(
                commercialBreakdownEstimated ? '商贷月供利息（反推）' : '商贷月供利息',
                row.commercialInterest,
              ),
              _moneyItem(
                row.commercialPaymentEvidence == LoanPaymentEvidence.estimated
                    ? '商贷月供合计（估算）'
                    : '商贷月供合计',
                row.commercialPayment,
              ),
              _optionalMoneyItem(
                '商贷月供减少',
                displayed.first
                    .valueFor(LoanPlanColumnKey.commercialReduction)
                    .amount,
              ),
            ],
          ),
          LoanDetailCard(
            title: '公积金月供构成',
            icon: Icons.home_work_outlined,
            items: [
              _moneyItem('公积金期初本金', row.providentOpening),
              if (row.providentAnnualRate case final rate?)
                _annualRateItem(
                  rate,
                  inferred: row.providentAnnualRateInferred,
                ),
              _moneyItem('公积金月供本金', row.providentPrincipal),
              _moneyItem(
                row.providentInterestEstimated ? '公积金月供利息（估算）' : '公积金月供利息',
                row.providentInterest,
              ),
              _moneyItem('公积金月供合计', row.providentPayment),
              _optionalMoneyItem(
                '公积金月供减少',
                displayed.first
                    .valueFor(LoanPlanColumnKey.providentReduction)
                    .amount,
              ),
            ],
          ),
          LoanDetailCard(
            title: '本月合计与现金流',
            icon: Icons.payments_outlined,
            items: [
              _moneyItem('月供合计', row.totalPayment),
              _optionalMoneyItem(
                '总额减少',
                displayed.first
                    .valueFor(LoanPlanColumnKey.totalReduction)
                    .amount,
              ),
              if (!row.isArchived) _moneyItem('可供提前还贷额', row.availableFunds),
              _moneyItem(
                row.expectedPrepaymentFromActual ? '预期提前还款（实还回填）' : '预期提前还款',
                row.expectedPrepayment,
              ),
              _optionalMoneyItem('实际提前还款', row.actualPrepayment),
              if (!row.expectedPrepaymentFromActual)
                _optionalMoneyItem('实际与预期差额', row.difference),
            ],
          ),
          LoanDetailCard(
            title: '提前还款汇总',
            icon: Icons.savings_outlined,
            items: [
              _moneyItem('实际使用提前还款', row.usedPrepayment),
              _moneyItem('其中商贷提前还款', row.commercialPrepayment),
              _moneyItem('其中公积金提前还款', row.providentPrepayment),
              if (row.prepaymentInterestRecorded)
                _moneyItem('当日提前利息', row.prepaymentInterestDueNow)
              else
                LoanDetailItem('当日提前利息', amountsMasked ? '****' : '待核'),
            ],
          ),
          if (row.prepaymentDetails.isEmpty)
            const LoanDetailCard(
              title: '提前还款明细',
              icon: Icons.receipt_long_outlined,
              items: [LoanDetailItem('本月明细', '无')],
            )
          else
            for (var index = 0; index < row.prepaymentDetails.length; index++)
              LoanPrepaymentDetailCard(
                index: index,
                detail: row.prepaymentDetails[index],
                line: displayed[index + (row.isArchived ? 1 : 0)],
                amountsMasked: amountsMasked,
                isArchived: row.isArchived,
              ),
          LoanDetailCard(
            title: '余额与下月月供变化',
            icon: Icons.account_balance_wallet_outlined,
            items: [
              if (row.isArchived) ...[
                _moneyItem(
                  '商贷正常扣款后余额',
                  row.commercialOpening - row.commercialPrincipal,
                ),
                _moneyItem(
                  '公积金正常扣款后余额',
                  row.providentOpening - row.providentPrincipal,
                ),
                _moneyItem('转息前月供', row.nextMonthBasePayment),
                _optionalMoneyItem(
                  '较上一行转息前月供减少',
                  displayed.first
                      .valueFor(LoanPlanColumnKey.nextMonthBaseReduction)
                      .amount,
                ),
                _moneyItem('转息差额', row.transferDifference),
              ] else ...[
                _moneyItem('下月基础月供', row.nextMonthBasePayment),
                _optionalMoneyItem('下月基础月供减少', nextMonthBasePaymentReduction),
                _moneyItem('转息差额', row.transferDifference),
              ],
              _moneyItem('商贷期末余额', row.commercialClosing),
              _moneyItem('公积金期末余额', row.providentClosing),
              _moneyItem('本金合计', row.totalBalance),
            ],
          ),
        ],
      ),
    );
  }
}

/// Renders one transaction within a month's prepayment details.
class LoanPrepaymentDetailCard extends StatelessWidget {
  const LoanPrepaymentDetailCard({
    super.key,
    required this.index,
    required this.detail,
    required this.line,
    required this.amountsMasked,
    this.isArchived = false,
  });

  final int index;
  final LoanPrepaymentDetail detail;
  final LoanPlanDisplayRow line;
  final bool amountsMasked;
  final bool isArchived;

  String _money(double value) =>
      formatLoanMoneyProtected(value, masked: amountsMasked);

  String _optionalMoney(double? value) {
    if (value == null) return amountsMasked ? '****' : '—';
    return _money(value);
  }

  String _date(String? value) {
    if (amountsMasked) return '****';
    return value == null || value.isBlank ? '—' : value;
  }

  @override
  Widget build(BuildContext context) {
    return LoanDetailCard(
      title: '提前还款明细 ${index + 1}',
      icon: Icons.receipt_long_outlined,
      items: [
        if (detail.eventId != null && detail.eventId!.isNotEmpty)
          LoanDetailItem('事件编号', detail.eventId!),
        LoanDetailItem('还贷日期', _date(detail.repaymentDate)),
        _moneyItem('本次使用金额', detail.amount),
        if (!isArchived) _moneyItem('预期金额', detail.expectedAmount),
        _optionalMoneyItem('实际金额', detail.actualPrepayment),
        if (detail.interestRecorded)
          _moneyItem('当日提前利息', detail.interestDueNow)
        else
          LoanDetailItem('当日提前利息', amountsMasked ? '****' : '待核'),
        if (isArchived && detail.interestRecorded)
          _moneyItem('实际扣款合计', detail.amount + detail.interestDueNow),
        if (!isArchived) _moneyItem('下月结转利息', detail.nextMonthDeferredInterest),
        if (detail.hasNormalPaymentBefore) ...[
          _moneyItem('本笔前商贷月供本金', detail.commercialPrincipalBefore),
          _moneyItem('本笔前商贷月供利息', detail.commercialInterestBefore),
          _moneyItem('本笔前商贷月供合计', detail.commercialPaymentBefore),
          _moneyItem('本笔前公积金月供本金', detail.providentPrincipalBefore),
          _moneyItem('本笔前公积金月供利息', detail.providentInterestBefore),
          _moneyItem('本笔前公积金月供合计', detail.providentPaymentBefore),
        ],
        if (detail.paymentAfter case final after?) ...[
          _moneyItem('本笔后商贷月供（测算）', after.commercial.payment),
          _moneyItem('本笔后公积金月供（测算）', after.provident.payment),
        ],
        if (line.previous != null)
          for (final column in const [
            LoanPlanColumnKey.commercialReduction,
            LoanPlanColumnKey.providentReduction,
            LoanPlanColumnKey.totalReduction,
            LoanPlanColumnKey.nextMonthBaseReduction,
          ])
            _optionalMoneyItem(
              '较上一行·${column.label}',
              line.valueFor(column).amount,
            ),
        _moneyItem('交易后商贷余额', detail.commercialClosing),
        _moneyItem('交易后公积金余额', detail.providentClosing),
        _moneyItem('交易后本金合计', detail.totalBalance),
      ],
    );
  }

  LoanDetailItem _moneyItem(String label, double value) =>
      LoanDetailItem(label, _money(value));

  LoanDetailItem _optionalMoneyItem(String label, double? value) =>
      LoanDetailItem(label, _optionalMoney(value));
}

/// Groups related month values into a responsive card.
class LoanDetailCard extends StatelessWidget {
  const LoanDetailCard({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<LoanDetailItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth < 420
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    for (final item in items)
                      SizedBox(width: itemWidth, child: item),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays one label/value pair inside a month detail card.
class LoanDetailItem extends StatelessWidget {
  const LoanDetailItem(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
