import 'package:flutter/material.dart';

import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_formatters.dart';

/// Responsive overview metrics for the current repayment plan.
class LoanPlanSummaryStrip extends StatelessWidget {
  const LoanPlanSummaryStrip({super.key, required this.viewModel});

  final LoanPlannerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final rows = viewModel.rows;
    final current = rows.firstWhere(
      (row) => row.month == viewModel.fixedPrepaymentMonths.first,
      orElse: () => rows.first,
    );
    final next = rows.firstWhere(
      (row) => row.month == viewModel.fixedPrepaymentMonths[1],
      orElse: () => current,
    );
    String amount(double value) =>
        formatLoanMoneyProtected(value, masked: viewModel.amountsMasked);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final cards = [
          LoanPlanMetricCard(
            label: '当前总余额',
            value: amount(
              viewModel.currentCommercialBalance +
                  viewModel.currentProvidentBalance,
            ),
            detail:
                '商贷 ${amount(viewModel.currentCommercialBalance)} · 公积金 ${amount(viewModel.currentProvidentBalance)}',
            icon: Icons.savings_outlined,
          ),
          LoanPlanMetricCard(
            label: '下月正常月供',
            value: amount(next.totalPayment),
            detail: '${next.month} · 商贷 ${amount(next.commercialPayment)}',
            icon: Icons.calendar_month_outlined,
          ),
          LoanPlanMetricCard(
            label: '预期结清',
            value: viewModel.expectedFinishMonth,
            detail: '当前模型共 ${rows.length} 个月',
            icon: Icons.flag_outlined,
          ),
          LoanPlanMetricCard(
            label: '已录入实际扣款',
            value: '${viewModel.actualOverrideCount} 笔',
            detail: '修改淡黄色单元格即可补正',
            icon: Icons.edit_note_outlined,
          ),
        ];
        if (wide) {
          return Row(
            children: cards
                .map(
                  (card) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: card,
                    ),
                  ),
                )
                .toList(),
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: constraints.maxWidth < 300
                      ? constraints.maxWidth
                      : 300,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

/// Displays one labeled repayment metric.
class LoanPlanMetricCard extends StatelessWidget {
  const LoanPlanMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: colors.secondaryContainer,
              child: Icon(icon, size: 20, color: colors.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
