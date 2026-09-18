import 'package:flutter/material.dart';

import '../../../../domain/models/loan_models.dart';

/// Selects the repayment formula shared by every loan calculation surface.
class LoanRepaymentMethodSelector extends StatelessWidget {
  const LoanRepaymentMethodSelector({
    super.key,
    required this.method,
    required this.onChanged,
  });

  final LoanRepaymentMethod method;
  final ValueChanged<LoanRepaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(
              '还款方式',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SegmentedButton<LoanRepaymentMethod>(
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                segments: [
                  for (final value in LoanRepaymentMethod.values)
                    ButtonSegment<LoanRepaymentMethod>(
                      value: value,
                      label: Text(value.label),
                    ),
                ],
                selected: {method},
                onSelectionChanged: (selection) => onChanged(selection.single),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
