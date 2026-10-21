import 'package:flutter/material.dart';

import '../../../../domain/services/basic_expression_calculator.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_calculator_keypad.dart';
import 'loan_calculator_layout_style.dart';
import 'loan_calculator_reference_widgets.dart';
import 'loan_calculator_workspace.dart';
import 'loan_plan_formatters.dart';

/// Calculator with live references and width-based E workspace arrangements.
class LoanCalculatorPage extends StatefulWidget {
  const LoanCalculatorPage({super.key, required this.viewModel});

  final LoanPlannerViewModel viewModel;

  @override
  State<LoanCalculatorPage> createState() => _LoanCalculatorPageState();
}

class _LoanCalculatorPageState extends State<LoanCalculatorPage> {
  final _expressionController = TextEditingController();
  final _referenceQueryController = TextEditingController();
  final _expressionKey = GlobalKey();
  final _calculator = const BasicExpressionCalculator();
  var _showAllReferences = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _expressionController.text = widget.viewModel.calculatorExpression;
    _expressionController.addListener(_persistExpression);
  }

  @override
  void dispose() {
    _expressionController.removeListener(_persistExpression);
    _expressionController.dispose();
    _referenceQueryController.dispose();
    super.dispose();
  }

  void _persistExpression() {
    widget.viewModel.updateCalculatorExpression(_expressionController.text);
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
      _calculator.evaluate(
        _expressionController.text,
        widget.viewModel.calculatorReferenceValues,
      );
      // Keep the formula available for review and for saving its process.
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
    widget.viewModel.saveTemporaryCalculatorResult(
      result,
      expression: _expressionController.text,
    );
    setState(() {});
  }

  void _insertTemporaryReference(CalculatorReference reference) {
    final expression = reference.expression;
    // A blank calculator shows the saved process; an existing formula uses
    // the staged number as one atomic reference.
    _append(
      _expressionController.text.isEmpty && expression != null
          ? '($expression)'
          : '【${reference.label}】',
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final result = _expressionController.text.isEmpty
          ? null
          : _tryResult(widget.viewModel.calculatorReferenceValues);
      if (constraints.maxWidth >= LoanCalculatorLayoutStyle.workspaceMinWidth) {
        return LoanCalculatorWorkspace(
          references: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('引用数值', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: LoanCalculatorLayoutStyle.gap),
              Expanded(child: _referenceSearch(scrollable: true)),
            ],
          ),
          calculator: ListView(
            primary: false,
            children: [
              Text('计算器', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: LoanCalculatorLayoutStyle.gap),
              _expressionField(),
              const SizedBox(height: LoanCalculatorLayoutStyle.gap),
              _resultText(result),
              const SizedBox(height: LoanCalculatorLayoutStyle.keyGap),
              _saveButton(result),
              const SizedBox(height: LoanCalculatorLayoutStyle.gap),
              _keypad(result: result, desktop: true),
            ],
          ),
          temporaryResults: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _temporaryHeading(),
              const SizedBox(height: LoanCalculatorLayoutStyle.keyGap),
              Expanded(
                child: widget.viewModel.temporaryCalculatorReferences.isEmpty
                    ? const Text('暂存计算结果后，可在这里查看原算式并再次插入。')
                    : ListView.builder(
                        primary: false,
                        itemCount: widget
                            .viewModel
                            .temporaryCalculatorReferences
                            .length,
                        itemBuilder: (context, index) {
                          final reference = widget
                              .viewModel
                              .temporaryCalculatorReferences[index];
                          return LoanCalculatorTemporaryCard(
                            reference: reference,
                            onSelected: () =>
                                _insertTemporaryReference(reference),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      }
      if (constraints.maxWidth >= LoanCalculatorLayoutStyle.landscapeMinWidth) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        return LoanCalculatorLandscape(
          minimumHeight: 260 + (_error == null ? 0 : 40) + (textScale - 1) * 80,
          expression: Row(
            children: [
              Expanded(child: _expressionField(compact: true)),
              const SizedBox(width: LoanCalculatorLayoutStyle.gap),
              SizedBox(
                width: constraints.maxWidth * .23,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: _resultText(result),
                ),
              ),
            ],
          ),
          keypad: _keypad(result: result, landscape: true),
          references: Column(
            children: [
              _referenceStrip(
                title: '首页数值',
                references: widget.viewModel.calculatorReferences
                    .where((item) => item.isHomeSummary)
                    .toList(),
                onSelected: (reference) => _append('【${reference.label}】'),
                action: TextButton(
                  onPressed: _openReferences,
                  child: const Text('全部引用'),
                ),
              ),
              _referenceStrip(
                title: '本次暂存',
                references: widget.viewModel.temporaryCalculatorReferences,
                onSelected: _insertTemporaryReference,
                action: TextButton(
                  onPressed: _clearTemporaryResults,
                  child: const Text('清空暂存'),
                ),
              ),
            ],
          ),
        );
      }
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: LoanCalculatorLayoutStyle.compactMaxWidth,
          ),
          child: _portrait(context),
        ),
      );
    },
  );

  Widget _expressionField({bool compact = false}) => TextField(
    key: _expressionKey,
    controller: _expressionController,
    readOnly: true,
    showCursor: true,
    minLines: 1,
    maxLines: compact ? 1 : 3,
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
  );

  Widget _resultText(double? result) => Text(
    result == null ? '结果：—' : '结果：${formatLoanMoney(result)}',
    style: Theme.of(context).textTheme.titleLarge?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _saveButton(double? result) => OutlinedButton.icon(
    onPressed: result == null ? null : () => _saveTemporaryResult(result),
    icon: const Icon(Icons.bookmark_add_outlined),
    label: const Text('暂存结果为引用值'),
  );

  void _clearTemporaryResults() {
    widget.viewModel.clearTemporaryCalculatorReferences();
    setState(() {});
  }

  Widget _temporaryHeading() => Row(
    children: [
      Expanded(
        child: Text('本次暂存', style: Theme.of(context).textTheme.titleMedium),
      ),
      TextButton(onPressed: _clearTemporaryResults, child: const Text('清空暂存')),
    ],
  );

  Widget _referenceSearch({bool scrollable = false}) =>
      LoanCalculatorReferenceSearch(
        references: widget.viewModel.calculatorReferences,
        matchesReference: widget.viewModel.matchesCalculatorReference,
        queryController: _referenceQueryController,
        scrollable: scrollable,
        onSelected: (reference) => _append('【${reference.label}】'),
      );

  void _openReferences() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .85,
        child: Padding(
          padding: const EdgeInsets.all(LoanCalculatorLayoutStyle.panelPadding),
          child: _referenceSearch(scrollable: true),
        ),
      ),
    );
  }

  Widget _referenceStrip({
    required String title,
    required List<CalculatorReference> references,
    required ValueChanged<CalculatorReference> onSelected,
    required Widget action,
  }) => Row(
    children: [
      Text(title, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(width: LoanCalculatorLayoutStyle.keyGap),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: references.isEmpty
              ? const Text('暂无暂存结果')
              : Row(
                  children: references
                      .map(
                        (reference) => Padding(
                          padding: const EdgeInsets.only(
                            right: LoanCalculatorLayoutStyle.keyGap,
                          ),
                          child: LoanCalculatorReferenceChip(
                            reference: reference,
                            onSelected: () => onSelected(reference),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ),
      action,
    ],
  );

  Widget _portrait(BuildContext context) {
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
        _expressionField(),
        const SizedBox(height: 12),
        _resultText(result),
        const SizedBox(height: 8),
        _saveButton(result),
        const SizedBox(height: 16),
        _keypad(result: result),
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
                  (reference) => LoanCalculatorReferenceChip(
                    reference: reference,
                    onSelected: () => _insertTemporaryReference(reference),
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
          LoanCalculatorReferenceSearch(
            references: visibleReferences,
            queryController: _referenceQueryController,
            matchesReference: widget.viewModel.matchesCalculatorReference,
            onSelected: (reference) => _append('【${reference.label}】'),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibleReferences
                .map(
                  (reference) => LoanCalculatorReferenceChip(
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

  Widget _keypad({
    double? result,
    bool landscape = false,
    bool desktop = false,
  }) => LoanCalculatorKeypad(
    onAppend: _append,
    onBackspace: _backspace,
    onCalculate: _calculate,
    onClear: _clearExpression,
    onSave: result == null ? null : () => _saveTemporaryResult(result),
    landscape: landscape,
    desktop: desktop,
  );
}
