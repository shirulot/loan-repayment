import 'package:flutter/material.dart';

import '../../../../domain/services/basic_expression_calculator.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_formatters.dart';

/// Phone calculator with live references to the repayment-plan overview.
class LoanCalculatorPage extends StatefulWidget {
  const LoanCalculatorPage({super.key, required this.viewModel});

  final LoanPlannerViewModel viewModel;

  @override
  State<LoanCalculatorPage> createState() => _LoanCalculatorPageState();
}

class _LoanCalculatorPageState extends State<LoanCalculatorPage> {
  final _expressionController = TextEditingController();
  final _calculator = const BasicExpressionCalculator();
  var _showAllReferences = false;
  String? _error;

  @override
  void dispose() {
    _expressionController.dispose();
    super.dispose();
  }

  void _append(String value) {
    final selection = _expressionController.selection;
    final start = selection.start < 0
        ? _expressionController.text.length
        : selection.start;
    final end = selection.end < 0 ? start : selection.end;
    final text = _expressionController.text.replaceRange(start, end, value);
    _expressionController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    setState(() => _error = null);
  }

  void _backspace() {
    final selection = _expressionController.selection;
    final end = selection.end < 0
        ? _expressionController.text.length
        : selection.end;
    final start = selection.start < 0 ? end : selection.start;
    if (start == 0 && end == 0) return;
    final removeStart = start == end ? start - 1 : start;
    final text = _expressionController.text.replaceRange(removeStart, end, '');
    _expressionController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: removeStart),
    );
    setState(() => _error = null);
  }

  void _calculate() {
    try {
      final result = _calculator.evaluate(
        _expressionController.text,
        widget.viewModel.calculatorReferenceValues,
      );
      // Editable loan fields use an empty string for zero, but a calculator
      // result must keep zero visible so the just-finished equation is clear.
      final resultText = result == 0 ? '0' : formatLoanEditableNumber(result);
      _expressionController.value = TextEditingValue(
        text: resultText,
        selection: TextSelection.collapsed(offset: resultText.length),
      );
      setState(() => _error = null);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  void _clearExpression() {
    _expressionController.clear();
    setState(() => _error = null);
  }

  void _saveTemporaryResult(double result) {
    widget.viewModel.saveTemporaryCalculatorResult(result);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final references = widget.viewModel.calculatorReferences;
    final visibleReferences = _showAllReferences
        ? references
        : references.where((item) => item.isHomeSummary).toList();
    final result = _expressionController.text.isEmpty
        ? null
        : _tryResult(widget.viewModel.calculatorReferenceValues);
    final temporaryReferences = widget.viewModel.temporaryCalculatorReferences;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        Text('计算器', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          '可直接输入四则运算，或点选下方数值插入引用。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _expressionController,
          readOnly: true,
          showCursor: true,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '算式',
            hintText: '例如：1000 + 【本月收入】',
            errorText: _error,
            suffixIcon: IconButton(
              tooltip: '一键置空',
              onPressed: _clearExpression,
              icon: const Icon(Icons.clear_outlined),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          result == null ? '结果：—' : '结果：${formatLoanMoney(result)}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: result == null ? null : () => _saveTemporaryResult(result),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('暂存结果为引用值'),
        ),
        const SizedBox(height: 16),
        _keypad(),
        const SizedBox(height: 24),
        if (temporaryReferences.isNotEmpty) ...[
          Row(
            children: [
              Text('本次暂存', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () {
                  widget.viewModel.clearTemporaryCalculatorReferences();
                  setState(() {});
                },
                child: const Text('清空暂存'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: temporaryReferences
                .map(
                  (reference) => _ReferenceChip(
                    reference: reference,
                    onSelected: () => _append('【${reference.label}】'),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
        ],
        Row(
          children: [
            Text('引用首页数值', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _showAllReferences = !_showAllReferences),
              icon: Icon(
                _showAllReferences ? Icons.expand_less : Icons.expand_more,
              ),
              label: Text(_showAllReferences ? '收起全部' : '展开全部'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_showAllReferences)
          _ReferenceSearch(
            references: visibleReferences,
            matchesReference: widget.viewModel.matchesCalculatorReference,
            onSelected: (reference) => _append('【${reference.label}】'),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibleReferences
                .map(
                  (reference) => _ReferenceChip(
                    reference: reference,
                    onSelected: () => _append('【${reference.label}】'),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  double? _tryResult(Map<String, double> references) {
    try {
      return _calculator.evaluate(_expressionController.text, references);
    } on FormatException {
      return null;
    }
  }

  Widget _keypad() {
    const keys = [
      '7',
      '8',
      '9',
      '÷',
      '4',
      '5',
      '6',
      '×',
      '1',
      '2',
      '3',
      '-',
      '.',
      '0',
      '(',
      '+',
    ];
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.45,
          children: keys
              .map(
                (key) => OutlinedButton(
                  onPressed: () => _append(key),
                  child: Text(key, style: const TextStyle(fontSize: 20)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _backspace,
                icon: const Icon(Icons.backspace_outlined),
                label: const Text('退格'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _append(')'),
                child: const Text(')'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _calculate,
                child: const Text('='),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReferenceSearch extends StatefulWidget {
  const _ReferenceSearch({
    required this.references,
    required this.matchesReference,
    required this.onSelected,
  });

  final List<CalculatorReference> references;
  final bool Function(CalculatorReference reference, String query)
  matchesReference;
  final ValueChanged<CalculatorReference> onSelected;

  @override
  State<_ReferenceSearch> createState() => _ReferenceSearchState();
}

class _ReferenceSearchState extends State<_ReferenceSearch> {
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

class _ReferenceChip extends StatelessWidget {
  const _ReferenceChip({required this.reference, required this.onSelected});

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
