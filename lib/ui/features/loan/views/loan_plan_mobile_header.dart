import 'package:flutter/material.dart';

import '../view_models/loan_planner_view_model.dart';

/// Header actions for the mobile loan overview.
class LoanMobilePageHeader extends StatelessWidget {
  const LoanMobilePageHeader({
    super.key,
    required this.viewModel,
    required this.onShowInfo,
  });

  final LoanPlannerViewModel viewModel;
  final VoidCallback onShowInfo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Icon(Icons.calculate_outlined, color: colors.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            '提前还贷计算器',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: viewModel.amountsMasked ? '显示金额' : '隐藏金额',
            onPressed: viewModel.toggleAmountsMasked,
            icon: Icon(
              viewModel.amountsMasked
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          IconButton(
            tooltip: '使用说明',
            onPressed: onShowInfo,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
    );
  }
}
