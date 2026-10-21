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
    this.queryController,
    this.scrollable = false,
  });

  final List<CalculatorReference> references;
  final bool Function(CalculatorReference reference, String query)
  matchesReference;
  final ValueChanged<CalculatorReference> onSelected;
  final TextEditingController? queryController;
  final bool scrollable;

  @override
  State<LoanCalculatorReferenceSearch> createState() =>
      _LoanCalculatorReferenceSearchState();
}

class _LoanCalculatorReferenceSearchState
    extends State<LoanCalculatorReferenceSearch> {
  var _query = '';

  @override
  void initState() {
    super.initState();
    widget.queryController?.addListener(_queryChanged);
  }

  @override
  void didUpdateWidget(covariant LoanCalculatorReferenceSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queryController != widget.queryController) {
      oldWidget.queryController?.removeListener(_queryChanged);
      widget.queryController?.addListener(_queryChanged);
    }
  }

  @override
  void dispose() {
    widget.queryController?.removeListener(_queryChanged);
    super.dispose();
  }

  void _queryChanged() {
    // A resized workspace and an open reference sheet can share the page's
    // query controller; both lists must reflect edits from either surface.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.references
        .where(
          (item) => widget.matchesReference(
            item,
            widget.queryController?.text.trim() ?? _query,
          ),
        )
        .toList();
    return Column(
      children: [
        TextField(
          controller: widget.queryController,
          onChanged: widget.queryController == null
              ? (value) => setState(() => _query = value.trim())
              : null,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: '搜索月份、农历月或列名，例如：八月、2026-08',
          ),
        ),
        const SizedBox(height: 8),
        if (widget.scrollable)
          Expanded(
            child: ListView.builder(
              primary: false,
              itemCount: entries.length,
              itemBuilder: (context, index) => _entry(entries[index]),
            ),
          ),
        if (!widget.scrollable) ...entries.map(_entry),
      ],
    );
  }

  Widget _entry(CalculatorReference reference) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(reference.label),
    subtitle: widget.scrollable ? Text(formatLoanMoney(reference.value)) : null,
    trailing: widget.scrollable ? null : Text(formatLoanMoney(reference.value)),
    onTap: () => widget.onSelected(reference),
  );
}

/// A saved process stays visible beside its insertable result in the workspace.
class LoanCalculatorTemporaryCard extends StatelessWidget {
  const LoanCalculatorTemporaryCard({
    super.key,
    required this.reference,
    required this.onSelected,
  });

  final CalculatorReference reference;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(reference.label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            formatLoanMoney(reference.value),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (reference.expression case final expression?) ...[
            const SizedBox(height: 8),
            Text(expression),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onSelected,
            icon: const Icon(Icons.input_outlined),
            label: const Text('点击插入'),
          ),
        ],
      ),
    ),
  );
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
