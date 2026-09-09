import 'package:flutter/material.dart';

import '../../../../domain/models/loan_models.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_formatters.dart';
import 'loan_plan_gesture_detector.dart';

/// Shows the selectable three-month repayment preview.
class LoanMobilePreviewSection extends StatelessWidget {
  const LoanMobilePreviewSection({
    super.key,
    required this.viewModel,
    required this.rows,
    required this.highlightedMonth,
    required this.onViewDetails,
    required this.onRowTap,
  });

  final LoanPlannerViewModel viewModel;
  final List<LoanPlanRow> rows;
  final String? highlightedMonth;
  final VoidCallback onViewDetails;
  final ValueChanged<String> onRowTap;

  String _money(double value) =>
      formatLoanMoneyProtected(value, masked: viewModel.amountsMasked);

  String _displayPreviewMonth(String month) {
    final parts = month.split('-');
    return '${parts[0]}年${int.parse(parts[1])}月';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '未来三个月还款预览',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400),
              ),
            ),
            TextButton.icon(
              onPressed: onViewDetails,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right, size: 18),
              label: const Text('查看详情'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.48),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              const LoanMobilePreviewRow(
                month: '月份',
                expected: '预计提前\n还款额',
                balance: '剩余\n本金',
                header: true,
              ),
              ...rows.map(
                (row) => LoanMobilePreviewRow(
                  month: _displayPreviewMonth(row.month),
                  expected: '¥${_money(row.expectedPrepayment)}',
                  balance: '¥${_money(row.totalBalance)}',
                  selected: row.month == highlightedMonth,
                  onTap: () => onRowTap(row.month),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '单击选中月份，再次单击进入详情。以上为预测结果，实际以还款后银行数据为准。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Renders one header or selectable row in the repayment preview.
class LoanMobilePreviewRow extends StatelessWidget {
  const LoanMobilePreviewRow({
    super.key,
    required this.month,
    required this.expected,
    required this.balance,
    this.header = false,
    this.selected = false,
    this.onTap,
  });

  final String month;
  final String expected;
  final String balance;
  final bool header;
  final bool selected;
  final VoidCallback? onTap;

  Widget _cell(
    BuildContext context,
    String value,
    TextStyle style, {
    bool withArrow = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
        if (withArrow)
          Icon(
            Icons.chevron_right,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 12,
      color: header ? colors.onSurfaceVariant : colors.onSurface,
      fontWeight: header ? FontWeight.w500 : FontWeight.w400,
    );
    return Material(
      color: Colors.transparent,
      child: LoanPlanGestureDetector(
        onTap: onTap,
        child: Container(
          height: header ? 34 : 44,
          decoration: BoxDecoration(
            color: selected
                ? colors.secondaryContainer
                : header
                ? colors.surfaceContainerHigh
                : null,
            border: Border(
              bottom: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.48),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(flex: 3, child: _cell(context, month, style)),
              Expanded(
                flex: 4,
                child: _cell(
                  context,
                  expected,
                  header ? style : style.copyWith(color: colors.error),
                ),
              ),
              Expanded(
                flex: 5,
                child: _cell(context, balance, style, withArrow: !header),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
