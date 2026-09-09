import 'package:flutter/material.dart';

import '../../../../domain/models/loan_models.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_calendar_formatters.dart';
import 'loan_plan_formatters.dart';

/// Shows one month's complete repayment data as vertically scrollable cards.
///
/// Pages keep the calculator's chronological order so the standard PageView
/// gesture moves left to the next month and right to the previous month.
class LoanMonthDetailPage extends StatefulWidget {
  const LoanMonthDetailPage({
    super.key,
    required this.viewModel,
    this.initialMonth,
  });

  final LoanPlannerViewModel viewModel;
  final String? initialMonth;

  @override
  State<LoanMonthDetailPage> createState() => _LoanMonthDetailPageState();
}

class _LoanMonthDetailPageState extends State<LoanMonthDetailPage> {
  late final PageController _pageController;
  late int _pageIndex;
  String? _currentMonth;

  @override
  void initState() {
    super.initState();
    final pages = _orderedRows();
    _currentMonth = widget.initialMonth;
    _pageIndex = _indexForMonth(pages, widget.initialMonth);
    _pageController = PageController(initialPage: _pageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<LoanPlanRow> _orderedRows() =>
      widget.viewModel.rows.toList(growable: false);

  int _indexForMonth(List<LoanPlanRow> rows, String? month) {
    if (rows.isEmpty || month == null) return 0;
    final index = rows.indexWhere((row) => row.month == month);
    return index < 0 ? 0 : index;
  }

  void _changePage(List<LoanPlanRow> pages, int index) {
    if (!mounted || index < 0 || index >= pages.length) return;
    setState(() {
      _pageIndex = index;
      _currentMonth = pages[index].month;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final pages = _orderedRows();
        if (pages.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('月详情')),
            body: const Center(child: Text('暂无还款计划数据。')),
          );
        }

        final currentIndex = _indexForMonth(
          pages,
          _currentMonth,
        ).clamp(0, pages.length - 1);
        final currentRow = pages[currentIndex];
        if (currentIndex != _pageIndex) {
          _pageIndex = currentIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_pageController.hasClients) return;
            final page = _pageController.page?.round();
            if (page != currentIndex) {
              _pageController.jumpToPage(currentIndex);
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('还款详情 · ${currentRow.month}'),
            actions: [
              IconButton(
                tooltip: widget.viewModel.amountsMasked ? '显示金额' : '隐藏金额',
                onPressed: widget.viewModel.toggleAmountsMasked,
                icon: Icon(
                  widget.viewModel.amountsMasked
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '左滑查看下个月 · 右滑查看上个月',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '${currentIndex + 1}/${pages.length}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (index) => _changePage(pages, index),
                    itemBuilder: (context, index) {
                      final row = pages[index];
                      // The calculator stores this reduction on the row that
                      // follows the repayment month. The detail card describes
                      // the current month's upcoming change, so read the next
                      // row; that value already includes all same-month
                      // prepayments through the cumulative closing balance.
                      final nextMonthBasePaymentReduction =
                          index + 1 < pages.length
                          ? pages[index + 1].nextMonthBasePaymentReduction
                          : null;
                      return _LoanMonthDetailContent(
                        key: ValueKey<String>('month-detail-${row.month}'),
                        row: row,
                        amountsMasked: widget.viewModel.amountsMasked,
                        nextMonthBasePaymentReduction:
                            nextMonthBasePaymentReduction,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoanMonthDetailContent extends StatelessWidget {
  const _LoanMonthDetailContent({
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
    return value == null || value.trim().isEmpty ? '—' : value;
  }

  _DetailItem _moneyItem(String label, double value) =>
      _DetailItem(label, _money(value));

  _DetailItem _optionalMoneyItem(String label, double? value) =>
      _DetailItem(label, _optionalMoney(value));

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
          _DetailCard(
            title: '月份与还款状态',
            icon: Icons.calendar_month_outlined,
            items: [
              _DetailItem('公历月份', row.month),
              _DetailItem('农历月份', formatLoanLunarMonth(row.month)),
              _DetailItem('剩余期数', '${row.remainingTerms} 期'),
              _DetailItem('还款状态', repaymentStatus),
              _DetailItem('计划还贷日期', _date(row.plannedPrepaymentDate)),
              _DetailItem('生效还贷日期', _date(row.effectivePrepaymentDate)),
              _DetailItem('实际生效日期', amountsMasked ? '****' : prepaymentDates),
            ],
          ),
          _DetailCard(
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
          _DetailCard(
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
          _DetailCard(
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
          _DetailCard(
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
            const _DetailCard(
              title: '提前还款明细',
              icon: Icons.receipt_long_outlined,
              items: [_DetailItem('本月明细', '无')],
            )
          else
            for (var index = 0; index < row.prepaymentDetails.length; index++)
              _PrepaymentDetailCard(
                index: index,
                detail: row.prepaymentDetails[index],
                amountsMasked: amountsMasked,
              ),
          _DetailCard(
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

class _PrepaymentDetailCard extends StatelessWidget {
  const _PrepaymentDetailCard({
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
    return value == null || value.trim().isEmpty ? '—' : value;
  }

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: '提前还款明细 ${index + 1}',
      icon: Icons.receipt_long_outlined,
      items: [
        if (detail.eventId != null && detail.eventId!.isNotEmpty)
          _DetailItem('事件编号', detail.eventId!),
        _DetailItem('还贷日期', _date(detail.repaymentDate)),
        _moneyItem('本次使用金额', detail.amount),
        _moneyItem('预期金额', detail.expectedAmount),
        _optionalMoneyItem('实际金额', detail.actualPrepayment),
        _moneyItem('当日提前利息', detail.interestDueNow),
        _moneyItem('下月结转利息', detail.nextMonthDeferredInterest),
        if (detail.hasNormalPaymentBefore) ...[
          _moneyItem('本笔后重算商贷月供本金', detail.commercialPrincipalBefore),
          _moneyItem('本笔后重算商贷月供利息', detail.commercialInterestBefore),
          _moneyItem('本笔后重算商贷月供合计', detail.commercialPaymentBefore),
          _moneyItem('本笔后重算公积金月供本金', detail.providentPrincipalBefore),
          _moneyItem('本笔后重算公积金月供利息', detail.providentInterestBefore),
          _moneyItem('本笔后重算公积金月供合计', detail.providentPaymentBefore),
        ],
        _moneyItem('交易后商贷余额', detail.commercialClosing),
        _moneyItem('交易后公积金余额', detail.providentClosing),
        _moneyItem('交易后本金合计', detail.totalBalance),
      ],
    );
  }

  _DetailItem _moneyItem(String label, double value) =>
      _DetailItem(label, _money(value));

  _DetailItem _optionalMoneyItem(String label, double? value) =>
      _DetailItem(label, _optionalMoney(value));
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<_DetailItem> items;

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

class _DetailItem extends StatelessWidget {
  const _DetailItem(this.label, this.value);

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
