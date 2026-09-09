import 'package:flutter/material.dart';

import '../../../../domain/models/loan_models.dart';
import '../view_models/loan_planner_view_model.dart';

/// Shows the overview model and projected finish-month explanation.
class LoanPlanIntroBanner extends StatelessWidget {
  const LoanPlanIntroBanner({super.key, required this.viewModel});

  final LoanPlannerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final rows = viewModel.rows;
    final fixedMonths = viewModel.fixedPrepaymentMonths;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '按当前模型滚动预测，实际扣款一经录入，后续自动补正',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_displayMonth(fixedMonths[0])} 为余额校准月；当前月供含银行结转息，转息前月供单独展示。预计结清：${_finishMonth(rows)}。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _finishMonth(List<LoanPlanRow> rows) {
    return rows
        .firstWhere((row) => row.totalBalance < 0.01, orElse: () => rows.last)
        .month;
  }

  String _displayMonth(String month) {
    final parts = month.split('-');
    return '${parts[0]}/${int.parse(parts[1])}';
  }
}
