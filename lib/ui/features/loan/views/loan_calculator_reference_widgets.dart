import 'package:flutter/material.dart';

import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_formatters.dart';

/// Filters the calculator references and inserts the selected value.
class LoanCalculatorReferenceSearch extends StatefulWidget {
  const LoanCalculatorReferenceSearch({
    super.key,
    required this.references,
    required this.matchesReference,
    required this.onSelected,
  });

  final List<CalculatorReference> references;
  final bool Function(CalculatorReference reference, String query)
  matchesReference;
  final ValueChanged<CalculatorReference> onSelected;

  @override
  State<LoanCalculatorReferenceSearch> createState() =>
      _LoanCalculatorReferenceSearchState();
}

class _LoanCalculatorReferenceSearchState
    extends State<LoanCalculatorReferenceSearch> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final entries = widget.references
        .where((item) => widget.matchesReference(item, _query))
        .toList();
    return Column(
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: '搜索月份、农历月或列名，例如：八月、2026-08',
          ),
        ),
        const SizedBox(height: 8),
        ...entries.map(
          (reference) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(reference.label),
            trailing: Text(formatLoanMoney(reference.value)),
            onTap: () => widget.onSelected(reference),
          ),
        ),
      ],
    );
  }
}

/// Displays a calculator reference as an insertable chip.
class LoanCalculatorReferenceChip extends StatelessWidget {
  const LoanCalculatorReferenceChip({
    super.key,
    required this.reference,
    required this.onSelected,
  });

  final CalculatorReference reference;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ActionChip(
    label: Text(
      '${reference.label} ${formatLoanEditableNumber(reference.value)}',
    ),
    onPressed: onSelected,
  );
}
