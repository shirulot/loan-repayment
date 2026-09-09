import 'package:flutter/material.dart';

import '../../../../core/extensions/string_extensions.dart';
import '../../../../domain/models/loan_models.dart';
import 'loan_plan_calendar_formatters.dart';
import 'loan_plan_formatters.dart';

/// Renders the complete data card list for one repayment month.
class LoanMonthDetailContent extends StatelessWidget {
  const LoanMonthDetailContent({
    super.key,
    required this.row,
    required this.amountsMasked,
    required this.nextMonthBasePaymentReduction,
  });

  final LoanPlanRow row;
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

  @override
  Widget build(BuildContext context) {
    final prepaymentDates = row.prepaymentDates.isEmpty
        ? '无'
        : row.prepaymentDates.join('、');
    final repaymentStatus = row.actualPrepayment != null
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
              _moneyItem('商贷月供本金', row.commercialPrincipal),
              _moneyItem('商贷月供利息', row.commercialInterest),
              _moneyItem('商贷月供合计', row.commercialPayment),
              _optionalMoneyItem('商贷月供减少', row.commercialReduction),
            ],
          ),
          LoanDetailCard(
            title: '公积金月供构成',
            icon: Icons.home_work_outlined,
            items: [
              _moneyItem('公积金期初本金', row.providentOpening),
              _moneyItem('公积金月供本金', row.providentPrincipal),
              _moneyItem('公积金月供利息', row.providentInterest),
              _moneyItem('公积金月供合计', row.providentPayment),
              _optionalMoneyItem('公积金月供减少', row.providentReduction),
            ],
          ),
          LoanDetailCard(
            title: '本月合计与现金流',
            icon: Icons.payments_outlined,
            items: [
              _moneyItem('月供合计', row.totalPayment),
              _optionalMoneyItem('总额减少', row.totalReduction),
              _moneyItem('可供提前还贷额', row.availableFunds),
              _moneyItem('预期提前还款', row.expectedPrepayment),
              _optionalMoneyItem('实际提前还款', row.actualPrepayment),
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
              _moneyItem('当日提前利息', row.prepaymentInterestDueNow),
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
                amountsMasked: amountsMasked,
              ),
          LoanDetailCard(
            title: '余额与下月月供变化',
            icon: Icons.account_balance_wallet_outlined,
            items: [
              _moneyItem('下月基础月供', row.nextMonthBasePayment),
              _optionalMoneyItem('下月基础月供减少', nextMonthBasePaymentReduction),
              _moneyItem('转息差额', row.transferDifference),
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
    required this.amountsMasked,
  });

  final int index;
  final LoanPrepaymentDetail detail;
  final bool amountsMasked;

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
        _moneyItem('预期金额', detail.expectedAmount),
        _optionalMoneyItem('实际金额', detail.actualPrepayment),
        _moneyItem('当日提前利息', detail.interestDueNow),
        _moneyItem('下月结转利息', detail.nextMonthDeferredInterest),
        if (detail.hasNormalPaymentBefore) ...[
          _moneyItem('本笔前商贷月供本金', detail.commercialPrincipalBefore),
          _moneyItem('本笔前商贷月供利息', detail.commercialInterestBefore),
          _moneyItem('本笔前商贷月供合计', detail.commercialPaymentBefore),
          _moneyItem('本笔前公积金月供本金', detail.providentPrincipalBefore),
          _moneyItem('本笔前公积金月供利息', detail.providentInterestBefore),
          _moneyItem('本笔前公积金月供合计', detail.providentPaymentBefore),
        ],
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
