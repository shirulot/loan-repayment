import 'package:flutter/material.dart';

import '../../../../domain/models/loan_models.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_formatters.dart';
import 'loan_plan_mobile_fields.dart';

/// Summarizes the editable monthly cash-flow values.
class LoanMobileCashFlowSummary extends StatelessWidget {
  const LoanMobileCashFlowSummary({
    super.key,
    required this.config,
    required this.viewModel,
    required this.onTap,
  });

  final LoanPlanConfig config;
  final LoanPlannerViewModel viewModel;
  final VoidCallback onTap;

  String _money(double value) =>
      formatLoanMoneyProtected(value, masked: viewModel.amountsMasked);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.primaryContainer.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.48),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 3.25,
                  children: [
                    _LoanMobileCashMetric(
                      label: '本月收入',
                      value: config.monthlySalary,
                      icon: Icons.account_balance_wallet_outlined,
                      amountsMasked: viewModel.amountsMasked,
                    ),
                    _LoanMobileCashMetric(
                      label: '额外收入',
                      value: config.monthlyExtraIncome,
                      icon: Icons.card_giftcard_outlined,
                      amountsMasked: viewModel.amountsMasked,
                    ),
                    _LoanMobileCashMetric(
                      label: '当月月供',
                      value: viewModel.currentMonthlyPayment,
                      icon: Icons.credit_card_outlined,
                      accent: true,
                      amountsMasked: viewModel.amountsMasked,
                    ),
                    _LoanMobileCashMetric(
                      label: '每月生活费',
                      value: config.monthlyLivingCost,
                      icon: Icons.coffee_outlined,
                      amountsMasked: viewModel.amountsMasked,
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.48),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.currency_yen_rounded,
                      color: colors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '可供提前还贷额',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '¥${_money(viewModel.currentAvailablePrepayment)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        color: colors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoanMobileCashMetric extends StatelessWidget {
  const _LoanMobileCashMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.amountsMasked,
    this.accent = false,
  });

  final String label;
  final double value;
  final IconData icon;
  final bool amountsMasked;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: accent ? colors.error : colors.primary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '¥${formatLoanMoneyProtected(value, masked: amountsMasked)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet editor for the monthly cash-flow values.
class LoanMobileCashFlowSheet extends StatelessWidget {
  const LoanMobileCashFlowSheet({
    super.key,
    required this.viewModel,
    required this.monthlySalaryController,
    required this.monthlySalaryFocusNode,
    required this.monthlyExtraIncomeController,
    required this.monthlyExtraIncomeFocusNode,
    required this.monthlyLivingCostController,
    required this.monthlyLivingCostFocusNode,
    required this.onSave,
  });

  final LoanPlannerViewModel viewModel;
  final TextEditingController monthlySalaryController;
  final FocusNode monthlySalaryFocusNode;
  final TextEditingController monthlyExtraIncomeController;
  final FocusNode monthlyExtraIncomeFocusNode;
  final TextEditingController monthlyLivingCostController;
  final FocusNode monthlyLivingCostFocusNode;
  final VoidCallback onSave;

  String _money(double value) =>
      formatLoanMoneyProtected(value, masked: viewModel.amountsMasked);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '编辑每月现金流',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            LoanMobileInputField(
              label: '本月收入',
              controller: monthlySalaryController,
              focusNode: monthlySalaryFocusNode,
              suffix: '元',
              amountsMasked: viewModel.amountsMasked,
            ),
            LoanMobileInputField(
              label: '额外收入',
              controller: monthlyExtraIncomeController,
              focusNode: monthlyExtraIncomeFocusNode,
              suffix: '元',
              amountsMasked: viewModel.amountsMasked,
            ),
            LoanMobileReadonlyField(
              label: '当月月供',
              value: _money(viewModel.currentMonthlyPayment),
              suffix: '元',
              amountsMasked: viewModel.amountsMasked,
            ),
            LoanMobileInputField(
              label: '每月生活费',
              controller: monthlyLivingCostController,
              focusNode: monthlyLivingCostFocusNode,
              suffix: '元',
              amountsMasked: viewModel.amountsMasked,
            ),
            LoanMobileReadonlyField(
              label: '可供提前还贷额',
              value: _money(viewModel.currentAvailablePrepayment),
              suffix: '元',
              highlight: true,
              amountsMasked: viewModel.amountsMasked,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onSave, child: const Text('保存现金流')),
          ],
        ),
      ),
    );
  }
}
